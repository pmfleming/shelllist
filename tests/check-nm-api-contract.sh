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
  (.data.fixture.network.security_class | IN("open", "enhanced-open", "legacy", "personal", "enterprise", "unknown")) and
  (.data.fixture.network.connect_prompt.kind | type == "string") and
  (.data.fixture.network.share.requires_profile_secret_check | type == "boolean") and
  (.data.fixture.network.portal_hint.auto_open_on_connect | type == "boolean") and
  (.data.fixture.network.key | type == "string") and
  (.data.fixture.network.access_points | type == "array") and
  (.data.fixture.status.enabled | type == "boolean") and
  (.data.fixture.status.radios.wireless_hardware_enabled | type == "boolean") and
  (.data.fixture.status.radios.wwan_enabled | type == "boolean") and
  (.data.fixture.status.radios.airplane_mode | type == "boolean") and
  (.data.fixture.status.connectivity.state | type == "string") and
  (.data.fixture.status.connectivity.check_enabled | type == "boolean") and
  (.data.fixture.status.ip4.addresses | type == "array") and
  (.data.fixture.status.ip4.routes | type == "array") and
  (.data.fixture.status.link.primary | type == "boolean") and
  (.data.fixture.status.device_path | type == "string") and
  (.data.fixture.status.ip4.dhcp_lease.server_identifier | type == "string") and
  (.data.fixture.status.ip4.dhcp_lease.domain_name | type == "string") and
  (.data.fixture.status.ip4.dhcp_lease.lease_time_seconds | type == "number") and
  (.data.fixture.status.ip4.dhcp_lease.expires_at_ms | type == "number") and
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
  .data.fixtures."wifi-networks.saved".snapshot.source == "cache" and
  .data.fixtures."wifi-networks.saved".networks[0].security_class == "personal" and
  .data.fixtures."wifi-networks.password-required".networks[0].capabilities.needs_password == true and
  .data.fixtures."wifi-networks.enterprise-required".networks[0].capabilities.needs_credentials == true and
  .data.fixtures."wifi-networks.enterprise-required".networks[0].connect_prompt.kind == "enterprise" and
  .data.fixtures."wifi-status.active".status.active == true and
  .data.fixtures."wifi-status.inactive".status.active == false and
  .data.fixtures."wifi-set-enabled.success".result.enabled == true and
  .data.fixtures."wifi-band.status".band.selected == "5" and
  .data.fixtures."wifi-band.set".result.stream == "wifi.band" and
  .data.fixtures."wifi-band.stream".events[-1].event == "cancelled" and
  .data.fixtures."radio-set-wwan-enabled.success".result.radios.wwan_enabled == true and
  .data.fixtures."radio-set-airplane-mode.success".result.radios.airplane_mode == true and
  .data.fixtures."wifi-connect.success".result.status == "connected" and
  .data.fixtures."wifi-connect.success".result.path == "dbus" and
  .data.fixtures."wifi-connect.secret-required".result.reason == "secret-required" and
  .data.fixtures."wifi-scan.stream".events[0].protocol == "nm-api" and
  .data.fixtures."wifi-scan.stream".events[0].stream == "wifi.scan" and
  .data.fixtures."wifi-profile.share".result.shareable == true and
  .data.fixtures."wifi-profile.details".result.version != null and
  (.data.fixtures."wifi-profile.details".result.enterprise.password_flags.agent_owned | type == "boolean") and
  .data.fixtures."wifi-profile.update-conflict".error.code == "conflict" and
  (.data.fixtures."wifi-status.active".status.ip6.addresses | type == "array") and
  (.data.fixtures."wifi-status.active".status.link.device_state_reason.category | type == "string") and
  (.data.fixtures."network-inventory.snapshot".inventory.devices | type == "array") and
  .data.fixtures."network-devices.list".devices[0].type_name == "wifi" and
  .data.fixtures."network-status.connected".network.state_name == "connected-global" and
  .data.fixtures."network-activate-profile.started".result.status == "activating" and
  .data.fixtures."network-deactivate.success".result.status == "deactivated" and
  .data.fixtures."network-statistics.watch".result.stream == "network.statistics" and
  .data.fixtures."hotspot.capabilities".hotspot.supported == true and
  .data.fixtures."hotspot.capabilities-unsupported".hotspot.unsupported_reason == "ap-mode-unsupported" and
  (.data.fixtures."hotspot.stream".events[] | select(.event == "succeeded") | .result.hotspot.share.qr_payload | startswith("WIFI:")) and
  .data.fixtures."vpn.list".vpns[0].plugin == "openconnect" and
  .data.fixtures."vpn.list".vpns[1].plugin == "wireguard" and
  (.data.fixtures."vpn.status-connected".vpn.active[0].vpn_state_name | type == "string") and
  (.data.fixtures."vpn.stream".events[] | select(.event == "failed") | .details.reason == "no-secrets") and
  .data.fixtures."wifi-qr.parse".qr.auth == "wpa" and
  .data.fixtures."wifi-qr.parse".qr.has_password == true and
  (.data.fixtures."wifi-qr.parse".qr | has("password") | not) and
  .data.fixtures."wifi-qr.parse-open".qr.auth == "open" and
  (.data.fixtures."network-health.stream".events[] | select(.event == "device") | .health.reason.category == "authentication")
' "$method_actual" >/dev/null

jq -e '
  .protocol == "nm-api" and
  .version == 1 and
  .ok == true and
  ([.data.protocol.methods[].name] | contains([
    "wifi.status", "wifi.setEnabled", "radio.setWwanEnabled", "radio.setAirplaneMode",
    "network.connectivity", "wifi.networks", "wifi.band.status", "wifi.band.set", "wifi.scan",
    "wifi.connectTarget", "wifi.disconnect", "wifi.profile.operation",
    "wifi.secret.capabilities", "wifi.secret.provide",
    "network.inventory", "network.devices", "network.connections", "network.status",
    "network.activateProfile", "network.deactivate", "network.statistics.watch",
    "hotspot.capabilities", "hotspot.status", "hotspot.start", "hotspot.stop",
    "vpn.list", "vpn.status", "vpn.connect", "vpn.disconnect",
    "wifi.qr.parse", "wifi.qr.connect"
  ])) and
  ([.data.protocol.streams[] | select(.subscribable) | .name] | contains([
    "wifi.status", "network.connectivity", "wifi.networks", "wifi.scan", "wifi.connect",
    "wifi.band", "wifi.secret", "network.inventory", "network.statistics", "hotspot", "vpn",
    "network.health"
  ]))
' "$registry_actual" >/dev/null

jq -r '
  def identifier: gsub("[.-]"; "_");
  ".pragma library\n.import \"NmProtocol.generated.js\" as Protocol\n\n"
  + "var protocol = Protocol.protocol;\n"
  + "var version = Protocol.version;\n\n"
  + "var methods = {\n"
  + ([.data.protocol.methods[]
      | select(.name == "wifi.setEnabled"
          or .name == "wifi.networks"
          or .name == "wifi.band.status"
          or .name == "wifi.band.set"
          or .name == "wifi.scan"
          or .name == "wifi.connectTarget"
          or .name == "wifi.disconnect"
          or .name == "wifi.profile.operation"
          or .name == "wifi.secret.provide"
          or .name == "wifi.qr.parse"
          or .name == "wifi.qr.connect"
          or .name == "network.inventory"
          or .name == "network.status"
          or .name == "network.activateProfile"
          or .name == "network.deactivate"
          or .name == "network.statistics.watch"
          or .name == "hotspot.capabilities"
          or .name == "hotspot.status"
          or .name == "hotspot.start"
          or .name == "hotspot.stop"
          or .name == "vpn.list"
          or .name == "vpn.status"
          or .name == "vpn.connect"
          or .name == "vpn.disconnect")
      | "    " + (.name | identifier) + ": Protocol.methods[" + (.name | tojson) + "]"] | join(",\n"))
  + "\n};\n\n"
  + "var streams = {\n"
  + ([.data.protocol.streams[] | select(.subscribable) | "    " + (.name | identifier) + ": Protocol.streams[" + (.name | tojson) + "]"] | join(",\n"))
  + "\n};\n\n"
  + "var subscribedStreams = [\n"
  + ([.data.protocol.streams[]
      | select(.name == "wifi.status"
          or .name == "network.connectivity"
          or .name == "wifi.networks"
          or .name == "wifi.scan"
          or .name == "wifi.connect"
          or .name == "wifi.band"
          or .name == "wifi.secret"
          or .name == "network.health")
      | "    streams." + (.name | identifier)] | join(",\n"))
  + "\n];\n\n"
  + "// Streams tied to an operation the shell starts on demand. Subscribing to\n"
  + "// them by default would make the daemon compute payloads nobody is reading.\n"
  + "var onDemandStreams = [\n"
  + ([.data.protocol.streams[]
      | select(.subscribable)
      | select(.name == "network.inventory"
          or .name == "network.statistics"
          or .name == "hotspot"
          or .name == "vpn")
      | "    streams." + (.name | identifier)] | join(",\n"))
  + "\n];"
' "$registry_actual" > "$frontend_actual"

diff -u "$frontend_api_js" "$frontend_actual"
