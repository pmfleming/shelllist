#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <nm-api-bin> <fixture>" >&2
  exit 2
fi

nm_api=$1
fixture=$2
actual=$(mktemp)
trap 'rm -f "$actual"' EXIT

"$nm_api" debug contract-fixture > "$actual"
diff -u "$fixture" "$actual"

jq -e '
  .protocol == "nm-api" and
  .version == 1 and
  .ok == true and
  (.data.fixture.network.capabilities.can_connect == true) and
  (.data.fixture.network.capabilities.needs_password | type == "boolean") and
  (.data.fixture.network.capabilities.needs_credentials | type == "boolean") and
  (.data.fixture.network.auth.note | type == "string") and
  (.data.fixture.network.access_points | type == "array") and
  (.data.fixture.status.connectivity.state | type == "string") and
  (.data.fixture.status.metered.state | type == "string") and
  (.data.fixture.status.wireless.tx_bitrate_mbps | type == "number") and
  (.data.fixture.status.wireless.rx_bitrate_mbps | type == "number") and
  (.data.fixture.status.access_point.last_seen_age_ms | type == "number") and
  (.data.fixture.connect_success.suggest_open_portal | type == "boolean") and
  .data.fixture.connect_error.status == "error" and
  .data.fixture.connect_error.reason == "secret-required"
' "$fixture" >/dev/null
