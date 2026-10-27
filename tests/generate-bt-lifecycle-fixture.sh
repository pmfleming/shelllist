#!/usr/bin/env bash
# Offline producer constructors only; no D-Bus, socket, hardware or effect dispatch.
set -euo pipefail
mode=${1:-check}
[[ $mode == check || $mode == generate ]] || { echo 'expected check or generate' >&2; exit 2; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
binary=${BT_DAEMON_BIN:-$root/../bt-daemon/target/debug/bt-daemon}
tool=${SHELLLIST_PROTOCOL_JS:-$root/../daemon-framework/target/debug/shelllist-protocol-js}
[[ -x $binary ]] || { echo "missing matching producer: $binary" >&2; exit 2; }
[[ -x $tool ]] || { echo "missing shared protocol generator: $tool" >&2; exit 2; }
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
RUST_LOG=off "$binary" debug contract-fixture > "$temporary/contract.json"
# The live constructors and frozen producer input must agree before publishing
# either frontend companion. Never regenerate from a stale producer binary.
python3 - "$temporary/contract.json" "$root/../bt-daemon/test_support/bt-api-v1.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as current, open(sys.argv[2]) as frozen:
    if json.load(current) != json.load(frozen):
        sys.exit("producer fixture differs from live constructors; rebuild/check the matching producer")
PY
python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["operation_ordering"], indent=2, sort_keys=True))' \
  < "$temporary/contract.json" > "$temporary/operations.json"
"$tool" < "$temporary/contract.json" > "$temporary/protocol.js"
# This BT-only entrypoint owns all BT fixture/binding companions; the shared
# all-domain generators remain unchanged and are not needed for a BT checkpoint.
render() {
  local input=$1 output=$2
  if [[ $mode == generate ]]; then cp "$input" "$root/$output";
  else diff -u "$root/$output" "$input"; fi
}
render "$temporary/contract.json" contracts/bt-api-ui-contract.fixture.json
render "$temporary/operations.json" tests/qml/fixtures/bt-operations.json
render "$temporary/protocol.js" bluetooth/BtProtocol.generated.js
