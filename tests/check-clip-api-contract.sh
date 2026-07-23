#!/usr/bin/env bash
set -euo pipefail

clip_daemon=${1:?clip-daemon binary required}
fixture=${2:?checked fixture required}
api_js=${3:?ClipApi.js required}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
"$clip_daemon" debug contract-fixture > "$tmp"
diff -u <(jq -S . "$fixture") <(jq -S . "$tmp")

while IFS= read -r name; do
  grep -Fq "\"$name\"" "$api_js" || {
    echo "ClipApi.js does not declare method $name" >&2
    exit 1
  }
done < <("$clip_daemon" debug protocol-registry | jq -r '.methods[].name')

while IFS= read -r name; do
  grep -Fq "\"$name\"" "$api_js" || {
    echo "ClipApi.js does not declare stream $name" >&2
    exit 1
  }
done < <("$clip_daemon" debug protocol-registry | jq -r '.streams[].name')

echo "clip-api contract: checked fixture and frontend registry match"
