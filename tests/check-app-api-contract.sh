#!/usr/bin/env bash
set -euo pipefail

app_daemon=${1:?app-daemon binary required}
fixture=${2:?checked fixture required}
api_js=${3:?AppApi.js required}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
"$app_daemon" debug contract-fixture > "$tmp"
diff -u <(jq -S . "$fixture") <(jq -S . "$tmp")

while IFS= read -r name; do
  grep -Fq "\"$name\"" "$api_js" || {
    echo "AppApi.js does not declare method $name" >&2
    exit 1
  }
done < <("$app_daemon" debug protocol-registry | jq -r '.methods[].name')

while IFS= read -r name; do
  grep -Fq "\"$name\"" "$api_js" || {
    echo "AppApi.js does not declare stream $name" >&2
    exit 1
  }
done < <("$app_daemon" debug protocol-registry | jq -r '.streams[].name')

echo "app-api contract: checked fixture and frontend registry match"
