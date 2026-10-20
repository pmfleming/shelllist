#!/usr/bin/env bash
# Offline producer constructors only; never call the running desktop services.
set -euo pipefail
mode=${1:-check}
[[ $mode == check || $mode == generate ]] || { echo 'expected check or generate' >&2; exit 2; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(cd -- "$root/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
export RUST_LOG=off
render() {
  local daemon=$1 command=$2 output=$3
  local binary="$projects/$daemon/target/debug/$daemon"
  [[ -x $binary ]] || { echo "missing freshly built producer: $binary" >&2; exit 2; }
  if [[ $daemon == nm-daemon ]]; then
    "$binary" --log-file "$temporary/nm.log" debug "$command" > "$temporary/value.json"
  else
    "$binary" debug "$command" > "$temporary/value.json"
  fi
  if [[ $mode == generate ]]; then cp "$temporary/value.json" "$root/$output";
  else diff -u "$root/$output" "$temporary/value.json"; fi
}
for daemon in app bar bt clip nm; do
  render "$daemon-daemon" contract-fixture "contracts/$daemon-api-ui-contract.fixture.json"
done
render app-daemon event-contract-fixture tests/qml/fixtures/app-events.json
render app-daemon reply-contract-fixture tests/qml/fixtures/app-replies.json
while read -r command file; do
  render bar-daemon "$command-contract-fixture" "tests/qml/fixtures/$file.json"
done <<'FIXTURES'
read bar-reads
control bar-controls
display bar-displays
notification bar-notification-actions
battery bar-battery
FIXTURES
