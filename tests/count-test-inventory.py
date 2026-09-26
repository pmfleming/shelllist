#!/usr/bin/env python3
"""Reproduce tests/README.md's mixed inventory; this is not a coverage metric."""
import argparse
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--revision", help="Git revision for source counts; defaults to the working tree")
parser.add_argument("--qml-log", required=True, type=Path, help="matching run-qml-tests.sh text output")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent


def git(*arguments):
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True)


def source(name):
    return git("show", f"{args.revision}:{name}") if args.revision else (root / name).read_text()


names = (git("ls-tree", "-r", "--name-only", args.revision).splitlines() if args.revision
         else [str(path.relative_to(root)) for directory in ("tests", "rust")
               for path in (root / directory).rglob("*") if path.is_file()])
# This expression is unchanged from the previous pruning inventory. Calls in
# loops/helpers count once per source site, not once per runtime invocation.
assertion = r"^\s*(?:assert\.\w+|expect|expectState|equal|near|ok|throws|compare)\("
javascript = sum(len(re.findall(assertion, source(name), re.M)) for name in names
                 if re.fullmatch(r"tests/check-.*\.js", name)
                 and name != "tests/check-packaged-imports.js")
rust = sum(len(re.findall(r"^\s*#\[test\]", source(name), re.M)) for name in names
           if name.startswith("rust/") and name.endswith(".rs"))
python = sum(len(re.findall(r"^\s*def test_\w+\(", source(name), re.M)) for name in names
             if re.fullmatch(r"tests/test_.*\.py", name))
# Contract declarations may use the shared apiContract builder or an inline derivation.
contracts = len(re.findall(r"^\s+\w+DaemonContract = (?:pkgs\.runCommand|apiContract)\b", source("flake.nix"), re.M))
log = args.qml_log.read_text()
totals = re.findall(r"Totals: (\d+) passed, (\d+) failed, (\d+) skipped, (\d+) blacklisted", log)
if len(totals) != 1 or any(int(value) for value in totals[0][1:]):
    parser.error("expected one complete QML run with zero failures, skips and blacklisted cases")
passes = re.findall(r"^PASS\s+: (.+)$", log, re.M)
if len(passes) != int(totals[0][0]):
    parser.error("QML pass lines do not match the runner total")
cases = [name for name in passes if "::test_" in name]
hooks = [name for name in passes if "::test_" not in name]
if any(not re.search(r"::(?:init|cleanup)TestCase\(\)$", name) for name in hooks):
    parser.error("unexpected non-behavioral QML case")
if not cases or len(cases) != len(set(cases)):
    parser.error("missing or duplicate QML behavioral cases")
counts = {"javascript_assertion_sites": javascript, "qml_behavioral_cases": len(cases),
          "rust_tests": rust, "python_tests": python, "daemon_contract_suites": contracts}
print(json.dumps({"revision": args.revision or "working tree", **counts,
                  "total_inventory_units": sum(counts.values()),
                  "qml_lifecycle_hooks_excluded": len(hooks)}, indent=2))
