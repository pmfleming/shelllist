#!/usr/bin/env bash
# Compares a daemon's contract fixture and protocol registry with the frontend.
#
# usage: check-api-contract.sh <label> <daemon-bin> <fixture> <assertions.jq> <coverage> <api-js>...
#   coverage "registry"  every registry method and stream is declared by the API files
#   coverage "api:<ERE>" every quoted "<ERE>.name" in the API files exists in the registry
set -euo pipefail

if [ "$#" -lt 6 ]; then
  sed -n '4,6s/^# \{0,1\}//p' "$0" >&2
  exit 2
fi
label=$1 daemon=$2 fixture=$3 assertions=$4 coverage=$5
shift 5

actual=$(mktemp)
trap 'rm -f "$actual"' EXIT
"$daemon" debug contract-fixture > "$actual"
diff -u <(jq -S . "$fixture") <(jq -S . "$actual")
jq -e -f "$assertions" "$fixture" >/dev/null

registry=$("$daemon" debug protocol-registry)
case "$coverage" in
  registry)
    while IFS= read -r name; do
      grep -Fqh "\"$name\"" "$@" || {
        echo "$label frontend does not declare $name" >&2
        exit 1
      }
    done < <(jq -r '(.methods + .streams)[].name' <<<"$registry")
    ;;
  api:*)
    while IFS= read -r name; do
      jq -e --arg name "$name" 'any((.methods + .streams)[]; .name == $name)' <<<"$registry" >/dev/null || {
        echo "$label frontend declares unknown protocol entry $name" >&2
        exit 1
      }
    done < <(grep -h -oE "\"(${coverage#api:})\\.[A-Za-z0-9.-]+\"" "$@" | tr -d '"' | sort -u)
    ;;
  *)
    echo "unknown coverage mode: $coverage" >&2
    exit 2
    ;;
esac

echo "$label contract: checked fixture and frontend registry match"
