#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <nm-daemon-bin> <fixture>" >&2
  exit 2
fi

nm_daemon=$1
fixture=$2
actual=$(mktemp)
method_actual=$(mktemp)
trap 'rm -f "$actual" "$method_actual"' EXIT

"$nm_daemon" debug contract-fixture > "$actual"
diff -u "$fixture" "$actual"
"$nm_daemon" debug contract-fixtures > "$method_actual"

jq -e '
  .protocol == "nm-api" and
  .version == 1 and
  .ok == true and
  (.data.fixture.network.capabilities.can_connect == true) and
  (.data.fixture.network.capabilities.needs_password | type == "boolean") and
  (.data.fixture.network.capabilities.needs_credentials | type == "boolean") and
  (.data.fixture.network.auth.note | type == "string") and
  (.data.fixture.network.connect_prompt.kind | type == "string") and
  (.data.fixture.network.share.requires_profile_secret_check | type == "boolean") and
  (.data.fixture.network.portal_hint.auto_open_on_connect | type == "boolean") and
  (.data.fixture.network.key | type == "string") and
  (.data.fixture.network.access_points | type == "array") and
  (.data.fixture.status.connectivity.state | type == "string") and
  (.data.fixture.status.metered.state | type == "string") and
  (.data.fixture.status.wireless.tx_bitrate_mbps | type == "number") and
  (.data.fixture.status.wireless.rx_bitrate_mbps | type == "number") and
  (.data.fixture.status.access_point.last_seen_age_ms | type == "number") and
  (.data.fixture.connect_success.suggest_open_portal | type == "boolean") and
  .data.fixture.connect_success.path == "dbus" and
  .data.fixture.connect_error.status == "error" and
  .data.fixture.connect_error.reason == "secret-required"
' "$fixture" >/dev/null

jq -e '
  .protocol == "nm-api" and
  .version == 1 and
  .ok == true and
  (.data.fixtures."wifi-networks.saved".networks | type == "array") and
  .data.fixtures."wifi-networks.password-required".networks[0].capabilities.needs_password == true and
  .data.fixtures."wifi-networks.enterprise-required".networks[0].capabilities.needs_credentials == true and
  .data.fixtures."wifi-networks.enterprise-required".networks[0].connect_prompt.kind == "enterprise" and
  .data.fixtures."wifi-status.active".status.active == true and
  .data.fixtures."wifi-status.inactive".status.active == false and
  .data.fixtures."wifi-connect.success".result.status == "connected" and
  .data.fixtures."wifi-connect.success".result.path == "dbus" and
  .data.fixtures."wifi-connect.secret-required".result.reason == "secret-required" and
  .data.fixtures."wifi-scan.stream".events[0].protocol == "nm-api" and
  .data.fixtures."wifi-scan.stream".events[0].stream == "wifi-scan" and
  .data.fixtures."wifi-profile.share".payload.shareable == true
' "$method_actual" >/dev/null
