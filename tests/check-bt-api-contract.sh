#!/usr/bin/env bash
set -euo pipefail

bt_daemon=${1:?bt-daemon binary required}
fixture=${2:?checked fixture required}
api_js=${3:?BtApi.js required}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
"$bt_daemon" debug contract-fixture > "$tmp"
diff -u <(jq -S . "$fixture") <(jq -S . "$tmp")

jq -e '
  .snapshot.data.snapshot.devices
  | all(.[]; (.signal_live | type == "boolean")
      and ((.signal_strength == null) or (.signal_strength | type == "number"))
      and ((.rssi == null) or (.rssi | type == "number"))
      and ((.last_seen_ms == null) or (.last_seen_ms | type == "number")))
' "$fixture" >/dev/null

registry=$("$bt_daemon" debug protocol-registry)
while IFS= read -r name; do
  jq -e --arg name "$name" 'any((.methods + .streams)[]; .name == $name)' <<<"$registry" >/dev/null || {
    echo "BtApi.js declares unknown protocol entry $name" >&2
    exit 1
  }
done < <(grep -oE '"(bluetooth|pairing)\.[A-Za-z0-9.]+"' "$api_js" | tr -d '"' | sort -u)

echo "bt-api contract: checked fixture and frontend registry match"
