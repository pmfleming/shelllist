#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <nm-wifi-bin> <fixture>" >&2
  exit 2
fi

nm_wifi=$1
fixture=$2
actual=$(mktemp)
trap 'rm -f "$actual"' EXIT

"$nm_wifi" contract-fixture > "$actual"
diff -u "$fixture" "$actual"

jq -e '
  .network.capabilities.can_connect == true and
  (.network.capabilities.needs_password | type == "boolean") and
  (.network.capabilities.needs_credentials | type == "boolean") and
  (.network.auth.note | type == "string") and
  (.network.access_points | type == "array") and
  (.status.connectivity.state | type == "string") and
  (.status.metered.state | type == "string") and
  (.status.wireless.tx_bitrate_mbps | type == "number") and
  (.status.wireless.rx_bitrate_mbps | type == "number") and
  (.status.access_point.last_seen_age_ms | type == "number") and
  (.connect_success.suggest_open_portal | type == "boolean") and
  .connect_error.status == "error" and
  .connect_error.reason == "secret-required"
' "$fixture" >/dev/null
