#!/usr/bin/env bash
set -euo pipefail

bar_daemon=${1:?bar-daemon binary required}
fixture=${2:?checked fixture required}
api_js=${3:?BarApi.js required}
activity_api_js=${4:-}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
"$bar_daemon" debug contract-fixture > "$tmp"
diff -u <(jq -S . "$fixture") <(jq -S . "$tmp")

jq -e '
  (.protocol == "bar-api") and
  (.version == 1) and
  (.snapshot.activity.event_count | type == "number") and
  (.snapshot.activity.incomplete_todo_count | type == "number") and
  (.snapshot.workspaces.monitors[0].active_workspace_id | type == "number") and
  (.snapshot.media.players[0].playback_status | type == "string") and
  (.snapshot.audio.volume_percent | type == "number") and
  (.snapshot.audio.input_available | type == "boolean") and
  (.snapshot.audio.input_muted | type == "boolean") and
  (.snapshot.brightness.percent | type == "number") and
  (.snapshot.battery.percentage | type == "number") and
  (.snapshot.power_profile.profile | type == "string") and
  (.snapshot.notifications.count | type == "number") and
  (.snapshot.updates.ready | type == "boolean") and
  (.snapshot.timezone.utc_offset_seconds | type == "number")
' "$fixture" >/dev/null

registry=$("$bar_daemon" debug protocol-registry)
while IFS= read -r name; do
  jq -e --arg name "$name" 'any((.methods + .streams)[]; .name == $name)' <<<"$registry" >/dev/null || {
    echo "BarApi.js declares unknown protocol entry $name" >&2
    exit 1
  }
done < <(grep -h -oE '"(bar|activity|todos|workspace|media|audio|brightness|battery|powerProfile|power-profile|notifications|updates|timezone)\.[A-Za-z0-9.-]+"' \
  "$api_js" ${activity_api_js:+"$activity_api_js"} | tr -d '"' | sort -u)

echo "bar-api contract: checked fixture and frontend registry match"
