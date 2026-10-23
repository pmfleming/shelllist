#!/usr/bin/env bash
# Thin QMLQualityLens adapter; collection and normalization live in Rust.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
perf=${SHELLLIST_PERF:-shelllist-perf}
if [[ $# == 1 && $1 == --version ]]; then
  "$perf" --version
  exec qmllint --version
fi
exec "$perf" profile-qml --root "$root" -- "$@"
