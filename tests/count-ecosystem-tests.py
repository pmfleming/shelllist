#!/usr/bin/env python3
"""Inventory registered ecosystem cases/suites; not assertions or a coverage metric.

Rust discovery logs must come from cargo test --workspace --all-features --lib
--tests --bins --locked -- --list. Keep logs matched to the counted source.
The established scope excludes external VM/desktop acceptance, manual captures,
static packaging checks and non-libtest benchmarks; it counts shared source once.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--workspace", type=Path, default=Path(__file__).resolve().parents[2])
parser.add_argument("--snapshot", type=Path, help="baseline archive with repository-prefixed paths")
parser.add_argument("--rust-logs", required=True, type=Path)
parser.add_argument("--rust-log-suffix", default="before")
parser.add_argument("--qml-log", required=True, type=Path)
parser.add_argument("--expected-qml-skip", action="append", default=[])
args = parser.parse_args()
repos = ["shelllist", "app-daemon", "bar-daemon", "bt-daemon", "clip-daemon",
         "nm-daemon", "update-daemon", "daemon-framework"]
archive = tarfile.open(args.snapshot) if args.snapshot else None
if archive:
    files = [member.name for member in archive.getmembers() if member.isfile()]
else:
    files = [f"{repo}/{name}" for repo in repos for name in subprocess.check_output(
        ["git", "-C", str(args.workspace / repo), "ls-files", "--cached", "--others", "--exclude-standard"],
        text=True).splitlines() if (args.workspace / repo / name).is_file()]


def source(name):
    return archive.extractfile(name).read().decode() if archive else (args.workspace / name).read_text()


qml = args.qml_log.read_text()
totals = re.findall(r"Totals: (\d+) passed, (\d+) failed, (\d+) skipped, (\d+) blacklisted", qml)
if len(totals) != 1 or int(totals[0][1]) or int(totals[0][3]):
    parser.error("expected one complete, passing QML run")
passes = re.findall(r"^PASS\s+: (\S+)", qml, re.M)
skips = re.findall(r"^SKIP\s+: (\S+::test_\S+)", qml, re.M)
if (len(passes) != int(totals[0][0]) or len(skips) != int(totals[0][2])
        or sorted(skips) != sorted(args.expected_qml_skip)):
    parser.error("QML totals/skips do not match the supplied evidence")
qml_cases = [name for name in passes if "::test_" in name] + skips
hooks = [name for name in passes if "::test_" not in name]
if any(not re.search(r"::(?:init|cleanup)TestCase\(\)$", name) for name in hooks):
    parser.error("unexpected non-behavioral QML entry")

inventory = {}
for repo in repos:
    cases = []
    for name in files:
        if not name.startswith(repo + "/"):
            continue
        if name.endswith(".py"):
            cases += [name + "::" + test for test in re.findall(r"^\s*def (test_\w+)\(", source(name), re.M)]
        if repo == "shelllist" and name.endswith(".rs"):
            cases += [name + "::" + test for test in re.findall(
                r"#\[(?:test|tokio::test)\]\s*(?:async )?fn (\w+)", source(name))]
    if repo == "shelllist":
        cases += qml_cases
        cases += [name for name in files if re.fullmatch(r"shelllist/tests/check-.*\.js", name)
                  and not name.endswith("check-packaged-imports.js")]
        cases += ["daemon-contract:" + name for name in re.findall(
            r"^\s+(\w+DaemonContract)\s*=\s*(?:pkgs\.runCommand|apiContract)\b", source("shelllist/flake.nix"), re.M)]
    else:
        log = (args.rust_logs / f"{repo}-{args.rust_log_suffix}.log").read_text()
        binary = ""
        rust = []
        for line in log.splitlines():
            if "Running " in line:
                binary = line.split("Running ", 1)[1].split(" (", 1)[0]
            match = re.fullmatch(r"(.+): test", line)
            if match:
                rust.append("cargo:" + binary + "::" + match[1])
        listed = re.findall(r"^(\d+) tests?, 0 benchmarks$", log, re.M)
        if not rust or not listed or len(rust) != sum(map(int, listed)) or re.search(r"^error(?:\[[^\]]+\])?: ", log, re.M):
            parser.error(f"incomplete or failing Rust discovery for {repo}")
        cases += rust
    if len(cases) != len(set(cases)):
        parser.error(f"duplicate cases in {repo}")
    inventory[repo] = sorted(cases)
print(json.dumps({"counts": {repo: len(cases) for repo, cases in inventory.items()},
                  "total": sum(map(len, inventory.values())),
                  "qml_existing_skips": skips, "cases": inventory}, indent=2))
