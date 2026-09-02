#!/usr/bin/env bash
set -euo pipefail

mode=${1:-check}
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(cd -- "$root/.." && pwd)
tool=${SHELLLIST_PROTOCOL_JS:-$projects/daemon-framework/target/debug/shelllist-protocol-js}

if [[ ! -x $tool ]]; then
  echo "missing protocol generator: $tool" >&2
  echo "build it with: cargo build -p shelllist-daemon-core --bin shelllist-protocol-js" >&2
  exit 2
fi

render() {
  local source=$1 output=$2 temporary
  if [[ $mode == generate ]]; then
    "$tool" < "$source" > "$output"
    return
  fi
  temporary=$(mktemp)
  "$tool" < "$source" > "$temporary"
  diff -u "$output" "$temporary"
  rm -f "$temporary"
}

render "$projects/app-daemon/test_support/app-api-v1.json" \
  "$root/launcher/AppProtocol.generated.js"
render "$projects/bar-daemon/test_support/bar-api-v1.json" \
  "$root/bar/BarProtocol.generated.js"
render "$projects/bt-daemon/test_support/bt-api-v1.json" \
  "$root/bluetooth/BtProtocol.generated.js"
render "$projects/clip-daemon/test_support/clip-api-v1.json" \
  "$root/clipboard/ClipProtocol.generated.js"

nm_registry=$(mktemp)
nm_log=$(mktemp)
trap 'rm -f "$nm_registry" "$nm_log"' EXIT
RUST_LOG=off "$projects/nm-daemon/target/debug/nm-daemon" \
  --log-file "$nm_log" debug protocol-registry > "$nm_registry"
render "$nm_registry" "$root/wifi/NmProtocol.generated.js"
