#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <nm-daemon-bin> <fixture> <frontend-api-js>" >&2
  exit 2
fi

nm_daemon=$1
fixture=$2
frontend_api_js=$3
actual=$(mktemp)
method_actual=$(mktemp)
registry_actual=$(mktemp)
frontend_actual=$(mktemp)
daemon_log=$(mktemp)
trap 'rm -f "$actual" "$method_actual" "$registry_actual" "$frontend_actual" "$daemon_log"' EXIT

"$nm_daemon" --log-file "$daemon_log" debug contract-fixture > "$actual"
diff -u "$fixture" "$actual"
"$nm_daemon" --log-file "$daemon_log" debug contract-fixtures > "$method_actual"
"$nm_daemon" --log-file "$daemon_log" debug protocol-registry > "$registry_actual"

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
  .data.fixtures."wifi-scan.stream".events[0].stream == "wifi.scan" and
  .data.fixtures."wifi-profile.share".payload.shareable == true
' "$method_actual" >/dev/null

jq -e '
  .protocol == "nm-api" and
  .version == 1 and
  .ok == true and
  ([.data.protocol.methods[].name] | contains([
    "wifi.status", "network.connectivity", "wifi.networks", "wifi.scan",
    "wifi.connectTarget", "wifi.disconnect", "wifi.profile.operation",
    "wifi.secret.capabilities", "wifi.secret.provide"
  ])) and
  ([.data.protocol.streams[] | select(.subscribable) | .name] | contains([
    "wifi.status", "network.connectivity", "wifi.scan", "wifi.connect", "wifi.secret"
  ]))
' "$registry_actual" >/dev/null

jq -r '
  def identifier: gsub("[.-]"; "_");
  ".pragma library\n\n"
  + "var protocol = " + (.protocol | tojson) + ";\n"
  + "var version = " + (.version | tostring) + ";\n\n"
  + "var methods = {\n"
  + ([.data.protocol.methods[] | "    " + (.name | identifier) + ": " + (.name | tojson)] | join(",\n"))
  + "\n};\n\n"
  + "var streams = {\n"
  + ([.data.protocol.streams[] | select(.subscribable) | "    " + (.name | identifier) + ": " + (.name | tojson)] | join(",\n"))
  + "\n};\n\n"
  + "var subscribedStreams = [\n"
  + ([.data.protocol.streams[] | select(.subscribable) | "    streams." + (.name | identifier)] | join(",\n"))
  + "\n];"
' "$registry_actual" > "$frontend_actual"

diff -u "$frontend_api_js" "$frontend_actual"
