#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output=${1:-"$repo_root/target/performance/qmlbench.json"}

exec node "$repo_root/tests/generate-performance-benchmarks.js" \
  "$repo_root/qml/Shelllist/Core/Model.js" "$output"
