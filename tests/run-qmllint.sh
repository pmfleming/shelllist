#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
ln -s "$repo_root/qml" "$workdir/qml"

mapfile -t sources < <(find \
  "$repo_root/qml" \
  "$repo_root/shell" \
  "$repo_root/bluetooth" \
  "$repo_root/clipboard" \
  "$repo_root/launcher" \
  "$repo_root/activity" \
  "$repo_root/wifi" \
  "$repo_root/tests/qml" \
  -type f -name '*.qml' | sort)

cd "$workdir"
shelllist-qmllint "${sources[@]}"
