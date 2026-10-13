#!/usr/bin/env python3
"""Check the captured multi-repository product, without network or Cargo resolution.

Default: sibling worktrees. --sources: JSON mapping repository names to captured
Nix inputs. Cargo --locked builds remain authoritative for feature resolution.
"""
import argparse
import collections
import json
import os
from pathlib import Path
import posixpath
import re
import sys
import tomllib


SECTIONS = ("dependencies", "dev-dependencies", "build-dependencies")


def toml(path):
    return tomllib.loads(path.read_text())


def dependencies(document):
    for section in SECTIONS:
        for name, spec in document.get(section, {}).items():
            yield name, {"version": spec} if isinstance(spec, str) else spec
    for target in document.get("target", {}).values():
        yield from dependencies(target)


def audit(policy, sources):
    errors = []

    def require(ok, message):
        if not ok:
            errors.append(message)

    def source(logical):
        repo, _, relative = logical.partition("/")
        return sources[repo] / relative

    require(set(sources) == set(policy["repositories"]), "captured repository set differs from policy")
    if errors:
        return errors
    manifests = {}
    discovered_locks = set()
    for repo in policy["repositories"]:
        root = sources[repo]
        require(toml(root / "rust-toolchain.toml")["toolchain"]["channel"] == policy["rust"],
                f"{repo}: rustup compiler differs from product compiler")
        for workflow in (root / ".github/workflows").glob("*.y*ml"):
            for channel in re.findall(r"(?m)^\s*(?:-\s*)?uses:\s*dtolnay/rust-toolchain@([^\s#]+)", workflow.read_text()):
                require(channel == policy["rust"], f"{repo}/{workflow.name}: CI compiler pin drift")
        lock = root / "flake.lock"
        if repo != "update-daemon":
            nodes = json.loads(lock.read_text())["nodes"]
            name = nodes["root"]["inputs"]["nixpkgs"]
            require(nodes[name]["locked"] == policy["nixpkgs"], f"{repo}: nixpkgs pin drift")
        # Discover new crates, but do not traverse build outputs or Git internals.
        for directory, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in {".git", "target", "node_modules"}]
            if "Cargo.lock" in files:
                relative = (Path(directory) / "Cargo.lock").relative_to(root)
                discovered_locks.add(f"{repo}/{relative}")
            if "Cargo.toml" in files:
                relative = (Path(directory) / "Cargo.toml").relative_to(root)
                manifests[f"{repo}/{relative}"] = toml(root / relative)
    require(set(manifests) == set(policy["manifests"]),
            f"manifest inventory changed: {sorted(set(manifests) ^ set(policy['manifests']))}")
    for path, reason in policy.get("nonOwningLocks", {}).items():
        require(bool(reason.strip()), f"{path}: undocumented non-owning lock")
    owning_locks = discovered_locks - set(policy.get("nonOwningLocks", {}))
    require(owning_locks == set(policy["locks"]),
            f"lock inventory changed: {sorted(owning_locks ^ set(policy['locks']))}")
    uses = collections.defaultdict(set)
    direct = collections.defaultdict(set)
    for path, manifest in manifests.items():
        minimum = manifest.get("package", manifest.get("workspace", {}).get("package", {})).get("rust-version")
        if isinstance(minimum, str):
            version = lambda s: tuple(int(v) for v in (s.split('.') + ['0', '0'])[:3])
            require(version(minimum) <= version(policy["rust"]), f"{path}: MSRV exceeds product compiler")
        for name, spec in dependencies(manifest):
            if "path" in spec:
                logical = posixpath.normpath(posixpath.join(posixpath.dirname(path), spec["path"], "Cargo.toml"))
                require(logical in manifests, f"{path}: uncaptured path dependency {logical}")
                require(not any(key in spec for key in ("git", "rev", "branch", "tag")),
                        f"{path}: mixed path/Git dependency {name}")
                continue
            name = spec.get("package", name)
            uses[name].add(path)
            owners = [lock for lock in policy["locks"] if path.startswith(posixpath.dirname(lock) + "/")]
            require(bool(owners), f"{path}: no captured owning lockfile")
            if owners:
                direct[max(owners, key=len)].add(name)
            if name in policy["shared"]:
                rule = policy["shared"][name]
                expected = rule.get("requirementExceptions", {}).get(path, {}).get("requirement", rule["requirement"])
                require(spec.get("version") == expected and "git" not in spec,
                        f"{path}: {name} requirement must be {expected}")
    shared = {name for name, locations in uses.items() if len(locations) > 1}
    require(shared <= set(policy["shared"]), f"unmanaged shared dependencies: {sorted(shared - set(policy['shared']))}")
    for lock_path in policy["locks"]:
        packages = toml(source(lock_path))["package"]
        require(direct[lock_path] <= {p["name"] for p in packages},
                f"{lock_path}: declared dependency missing from lock")
        for name, rule in policy["shared"].items():
            found = [p for p in packages if p["name"] == name]
            if not found:
                continue
            exception = rule.get("lockExceptions", {}).get(lock_path)
            expected = exception["versions"] if exception else [rule["version"]]
            require(sorted(p["version"] for p in found) == sorted(expected),
                    f"{lock_path}: {name} resolution drift (expected {expected})")
            require(all(p.get("source") == "registry+https://github.com/rust-lang/crates.io-index"
                        and p.get("checksum") for p in found), f"{lock_path}: {name} source/checksum drift")
    for name, rule in policy["shared"].items():
        for kind in ("requirementExceptions", "lockExceptions"):
            for path, exception in rule.get(kind, {}).items():
                require(bool(exception.get("reason", "").strip()), f"{name}/{path}: undocumented exception")
                require(path in (manifests if kind == "requirementExceptions" else policy["locks"]),
                        f"{name}/{path}: stale exception")
    # Keep the intentional vendored search exception executable until consolidation.
    canonical = sources["shelllist"] / "rust/shelllist-search"
    vendored = sources["clip-daemon"] / "vendor/shelllist-search"
    def search_files(root):
        return {str(p.relative_to(root)): p.read_bytes()
                for p in [root / "Cargo.toml", *sorted((root / "src").rglob("*"))] if p.is_file()}
    require(search_files(canonical) == search_files(vendored), "vendored search differs from canonical source")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path)
    parser.add_argument("--policy", type=Path, default=Path(__file__).resolve().parents[1] / "contracts/build-inputs.json")
    args = parser.parse_args()
    policy = json.loads(args.policy.read_text())
    parent = Path(__file__).resolve().parents[2]
    sources = ({key: Path(value) for key, value in json.loads(args.sources.read_text()).items()}
               if args.sources else {repo: parent / repo for repo in policy["repositories"]})
    try:
        errors = audit(policy, sources)
    except (OSError, KeyError, ValueError) as error:
        errors = [f"incomplete/invalid captured product: {error}"]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"build inputs aligned: Rust {policy['rust']}, {len(policy['locks'])} locked roots, {len(policy['shared'])} shared dependencies")
    return 0


if __name__ == "__main__":
    sys.exit(main())
