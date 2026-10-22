#!/usr/bin/env python3
"""Fault-inject build drift into isolated fixtures, never the worktrees."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

checker = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).parents[1] / "tools/check-build-inputs.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("build_inputs", checker)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BuildInputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sources = {repo: self.root / repo for repo in ("shelllist", "clip-daemon")}
        self.manifests = ["shelllist/rust/shelllist-search/Cargo.toml", "clip-daemon/vendor/shelllist-search/Cargo.toml"]
        self.locks = [str(Path(p).with_name("Cargo.lock")) for p in self.manifests]
        for root in self.sources.values():
            root.mkdir()
            (root / "rust-toolchain.toml").write_text('[toolchain]\nchannel = "1.95.0"\n')
            (root / "flake.lock").write_text(json.dumps({"nodes": {
                "root": {"inputs": {"nixpkgs": "pkgs"}}, "pkgs": {"locked": {"rev": "pinned"}}
            }}))
        for manifest, lock in zip(self.manifests, self.locks):
            self.put(manifest, '[package]\nname = "search"\nversion = "0.1.0"\nrust-version = "1.85"\n[dependencies]\nserde = "1"\n')
            self.put(str(Path(manifest).parent / "src/lib.rs"), '// canonical\n')
            self.put(lock, 'version = 4\n[[package]]\nname = "serde"\nversion = "1.0.229"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "test-only"\n')
        self.policy = {
            "repositories": list(self.sources), "manifests": self.manifests,
            "locks": self.locks, "rust": "1.95.0", "nixpkgs": {"rev": "pinned"},
            "shared": {"serde": {"requirement": "1", "version": "1.0.229"}}
        }

    def put(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def replace(self, path, old, new):
        file = self.root / path
        file.write_text(file.read_text().replace(old, new))

    def errors(self):
        return module.audit(self.policy, self.sources)

    def rejects(self, text):
        self.assertTrue(any(text in e for e in self.errors()), self.errors())

    def test_aligned(self):
        self.assertEqual(self.errors(), [])

    def test_compiler_drift(self):
        self.replace("shelllist/rust-toolchain.toml", "1.95.0", "stable")
        self.rejects("rustup compiler")

    def test_ci_compiler_drift(self):
        path = "shelllist/.github/workflows/ci.yml"
        self.put(path, 'jobs:\n  test:\n    steps:\n      - uses: dtolnay/rust-toolchain@stable\n')
        self.rejects("CI compiler pin drift")
        self.replace(path, '@stable', '@1.95.0')
        self.assertEqual(self.errors(), [])

    def test_nixpkgs_drift(self):
        self.replace("shelllist/flake.lock", "pinned", "other")
        self.rejects("nixpkgs pin")

    def test_requirement_drift(self):
        self.replace(self.manifests[0], 'serde = "1"', 'serde = "2"')
        self.rejects("requirement must be")

    def test_lock_drift_and_duplicate(self):
        self.replace(self.locks[0], '1.0.229', '1.0.228')
        self.rejects("resolution drift")
        self.put(self.locks[0], (self.root / self.locks[1]).read_text() + '\n[[package]]\nname = "serde"\nversion = "1.0.228"\n')
        self.rejects("resolution drift")

    def test_missing_locked_dependency(self):
        self.put(self.locks[0], 'version = 4\npackage = []\n')
        self.rejects("declared dependency missing")

    def test_new_lock_inventory(self):
        self.put("shelllist/new/Cargo.lock", 'version = 4\npackage = []\n')
        self.rejects("lock inventory changed")

    def test_source_drift(self):
        self.replace(self.locks[0], 'registry+https://github.com/rust-lang/crates.io-index', 'git+https://example.invalid/serde')
        self.rejects("source/checksum")

    def test_new_shared_dependency_requires_policy(self):
        for manifest in self.manifests:
            self.put(manifest, (self.root / manifest).read_text() + 'tokio = "1"\n')
        self.rejects("unmanaged shared dependencies")

    def test_uncaptured_path(self):
        self.put(self.manifests[0], (self.root / self.manifests[0]).read_text() + 'missing = { path = "../../../../outside" }\n')
        self.rejects("uncaptured path dependency")

    def test_new_crate_inventory(self):
        self.put("shelllist/new/Cargo.toml", '[package]\nname = "new"\n')
        self.rejects("manifest inventory changed")

    def independent_crate(self):
        path = "shelllist/tools/lens/Cargo.toml"
        self.put(path, '[package]\nname = "lens"\nversion = "0.1.0"\n[workspace]\n[dependencies]\nserde = "2"\n')
        self.put("shelllist/tools/lens/Cargo.lock", 'version = 4\npackage = []\n')
        self.policy["independentCrates"] = {path: "External tool, not a product dependency"}
        return path

    def test_independent_crate_has_separate_dependency_policy(self):
        self.independent_crate()
        self.assertEqual(self.errors(), [])

    def test_independent_crate_requires_reason_and_present_manifest(self):
        path = self.independent_crate()
        self.policy["independentCrates"][path] = ""
        self.rejects("undocumented independent crate")
        (self.root / path).unlink()
        self.rejects("stale independent crate")

    def test_independent_crate_requires_standalone_workspace_and_lock(self):
        path = self.independent_crate()
        self.replace(path, '[workspace]\n', '')
        self.rejects("empty standalone workspace")
        (self.root / path).with_name("Cargo.lock").unlink()
        self.rejects("own a separate lockfile")

    def test_independent_crate_cannot_also_be_product(self):
        path = self.independent_crate()
        self.policy["manifests"].append(path)
        self.policy["locks"].append(str(Path(path).with_name("Cargo.lock")))
        self.rejects("also a product manifest")
        self.rejects("own a separate lockfile")

    def test_independent_crate_does_not_hide_nested_crates(self):
        self.independent_crate()
        self.put("shelllist/tools/lens/nested/Cargo.toml", '[package]\nname = "nested"\n')
        self.put("shelllist/tools/lens/nested/Cargo.lock", 'version = 4\npackage = []\n')
        self.rejects("manifest inventory changed")
        self.rejects("lock inventory changed")

    def test_product_cannot_depend_on_independent_crate(self):
        self.independent_crate()
        path = self.manifests[0]
        self.put(path, (self.root / path).read_text() + 'lens = { path = "../../tools/lens" }\n')
        self.rejects("uncaptured path dependency shelllist/tools/lens/Cargo.toml")

    def test_msrv(self):
        self.replace(self.manifests[0], '1.85', '1.96')
        self.rejects("MSRV exceeds")

    def test_missing_source(self):
        del self.sources["clip-daemon"]
        self.rejects("captured repository set")

    def test_search_drift(self):
        self.put("clip-daemon/vendor/shelllist-search/src/lib.rs", '// divergent\n')
        self.rejects("vendored search differs")

    def test_documented_exception_is_narrow(self):
        self.replace(self.locks[0], '1.0.229', '1.0.228')
        self.policy["shared"]["serde"]["lockExceptions"] = {
            self.locks[0]: {"versions": ["1.0.228"], "reason": "synthetic compatibility test"}
        }
        self.assertEqual(self.errors(), [])
        self.replace(self.locks[1], '1.0.229', '1.0.228')
        self.rejects("resolution drift")

    def test_requirement_exception_is_narrow(self):
        self.replace(self.manifests[0], 'serde = "1"', 'serde = "1.0.229"')
        self.policy["shared"]["serde"]["requirementExceptions"] = {
            self.manifests[0]: {"requirement": "1.0.229", "reason": "synthetic independent upgrade"}
        }
        # These fixtures double as canonical/vendored search: the manifest
        # change is allowed by dependency policy, but still violates parity.
        self.assertEqual(self.errors(), ["vendored search differs from canonical source"])
        self.replace(self.manifests[1], 'serde = "1"', 'serde = "1.0.229"')
        self.rejects("requirement must be")

    def test_exception_requires_reason(self):
        self.policy["shared"]["serde"]["lockExceptions"] = {
            self.locks[0]: {"versions": ["1.0.229"]}
        }
        self.rejects("undocumented exception")


if __name__ == "__main__":
    unittest.main()
