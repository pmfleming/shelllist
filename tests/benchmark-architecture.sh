#!/usr/bin/env bash
# Run in the product development shell. Private bus/fake launcher only.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(dirname "$root")
output=${1:-"$root/target/performance/architecture"}
mkdir -p "$output"
output=$(cd "$output" && pwd)
(cd "$projects/app-daemon" && cargo test --locked --test session bridge::reliability_baseline -- --ignored --exact --nocapture) > "$output/app.log" 2>&1
(cd "$projects/bar-daemon" && cargo test --locked --lib state::events::reliability_tests::measured_domain_delivery_baseline -- --exact --nocapture) > "$output/bar.log" 2>&1
python3 - "$output" "$projects" "${QML_LOG:-}" <<'PY'
import json, pathlib, subprocess, sys
out, projects = map(pathlib.Path, sys.argv[1:3])
samples = []
for name in ('app', 'bar'):
    lines = (out / (name + '.log')).read_text().splitlines()
    records = [json.loads(line.split('SHELLLIST_RELIABILITY ', 1)[1]) for line in lines if line.startswith('SHELLLIST_RELIABILITY ')]
    if len(records) != 1:
        raise SystemExit(f'{name}: expected exactly one completed benchmark record')
    samples.extend(records)
if sys.argv[3]:
    lines = pathlib.Path(sys.argv[3]).read_text().splitlines()
    if not any('0 failed' in line and 'Totals:' in line for line in lines):
        raise SystemExit('QML evidence is not a completed passing run')
    records = [json.loads(line.split('SHELLLIST_RELIABILITY ', 1)[1]) for line in lines if 'SHELLLIST_RELIABILITY ' in line]
    if not records:
        raise SystemExit('QML evidence has no recovery measurement')
    samples.extend(records)
sources = {}
for name in ('daemon-framework', 'app-daemon', 'bar-daemon', 'shelllist'):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(projects / name), *args], text=True).strip()
    sources[name] = {'commit': git('rev-parse', 'HEAD'), 'worktree_dirty': bool(git('status', '--porcelain'))}
report = {'schema_version': 1, 'sources': sources, 'samples': samples,
          'limitations': ['Debug builds, not release latency budgets.', 'Synthetic domains and private-bus fixtures, not all five deployed services.', 'Run repeatedly on an otherwise idle host before comparing; no process split is justified by one sample.']}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
PY
