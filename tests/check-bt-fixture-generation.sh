#!/usr/bin/env bash
# Generator orchestration regression only. Synthetic offline executables, no buses
# or effects; real producer/shared-generator parity is checked separately.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
fixture_root="$temporary/shelllist"
mkdir -p "$fixture_root/tests/qml/fixtures" "$fixture_root/contracts" "$fixture_root/bluetooth" \
  "$temporary/bt-daemon/test_support"
cp "$root/tests/generate-bt-lifecycle-fixture.sh" "$fixture_root/tests/"
cp "$root/../bt-daemon/test_support/bt-api-v1.json" "$temporary/bt-daemon/test_support/"
export FAKE_BT_FIXTURE="$temporary/bt-daemon/test_support/bt-api-v1.json"
export FAKE_BT_TOOL_MARKER="$temporary/tool-called"
export BT_DAEMON_BIN="$temporary/producer" SHELLLIST_PROTOCOL_JS="$temporary/generator"
cat > "$BT_DAEMON_BIN" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 && $1 == debug && $2 == contract-fixture ]]
python3 - "$FAKE_BT_FIXTURE" "${FAKE_BT_STALE:-0}" <<'PY'
import json
import sys
with open(sys.argv[1]) as source:
    fixture = json.load(source)
if sys.argv[2] == "1":
    fixture["operation_ordering"]["queued"]["revision"] = 0
print(json.dumps(fixture, indent=2))
PY
SH
cat > "$SHELLLIST_PROTOCOL_JS" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf called > "$FAKE_BT_TOOL_MARKER"
# A partial stdout followed by failure must not publish any companion.
printf '%s\n' '// synthetic binding'
[[ ${FAKE_BT_GENERATOR_FAIL:-0} != 1 ]]
python3 -c 'import json,sys; json.load(sys.stdin)'
SH
chmod +x "$BT_DAEMON_BIN" "$SHELLLIST_PROTOCOL_JS"
outputs=(contracts/bt-api-ui-contract.fixture.json tests/qml/fixtures/bt-operations.json bluetooth/BtProtocol.generated.js)
for output in "${outputs[@]}"; do printf untouched > "$fixture_root/$output"; done
generator="$fixture_root/tests/generate-bt-lifecycle-fixture.sh"
expect_failure() {
  if "$@" > "$temporary/expected-negative.log" 2>&1; then
    echo 'Expected generator rejection' >&2; exit 1
  fi
}
assert_unpublished() {
  for output in "${outputs[@]}"; do
    [[ $(< "$fixture_root/$output") == untouched ]] || { echo "published before validation: $output" >&2; exit 1; }
  done
}
expect_failure env FAKE_BT_STALE=1 bash "$generator" generate
assert_unpublished
[[ ! -e $FAKE_BT_TOOL_MARKER ]] || { echo 'stale producer reached generator' >&2; exit 1; }
expect_failure env FAKE_BT_GENERATOR_FAIL=1 bash "$generator" generate
assert_unpublished
expect_failure bash "$generator" check
expect_failure bash "$generator" invalid-mode
expect_failure env BT_DAEMON_BIN="$temporary/missing" bash "$generator" generate
expect_failure env SHELLLIST_PROTOCOL_JS="$temporary/missing" bash "$generator" generate
assert_unpublished
bash "$generator" generate
bash "$generator" check
# Every companion, not only the focused operation fixture, must detect drift.
for output in "${outputs[@]}"; do
  printf drift > "$fixture_root/$output"
  expect_failure bash "$generator" check
  bash "$generator" generate
  bash "$generator" check
done
printf '%s\n' 'BT fixture generator: stale/missing inputs, failed rendering, all-companion drift and generation passed'
