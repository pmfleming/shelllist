#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
qt_root=$(cd "$(dirname "$(readlink -f "$(command -v qmllint)")")/.." && pwd)
quickshell_root=$(cd "$(dirname "$(readlink -f "$(command -v quickshell)")")/.." && pwd)

# qmllint resolves a source both through its physical feature directory and the
# Shelllist.* import symlink when run at the repository root. Run from an empty
# directory, as the authoritative lint check does, and make lens source paths
# absolute so the duplicate type identities cannot mask real diagnostics.
options=()
sources=()
shortcut_sources=()
source_arguments=false
for argument in "$@"; do
  if [[ "$argument" == "--" ]]; then
    source_arguments=true
  elif $source_arguments; then
    source="$argument"
    [[ "$source" == /* ]] || source="$repo_root/$source"
    if [[ "$source" == */ShelllistGlobalShortcut.qml ]]; then
      shortcut_sources+=("$source")
    else
      sources+=("$source")
    fi
  else
    options+=("$argument")
  fi
done

if ! $source_arguments; then
  exec qmllint "${options[@]}"
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"
imports=(-I "$qt_root/lib/qt-6/qml" -I "$quickshell_root/lib/qt-6/qml")
if ((${#sources[@]} > 0)); then
  qmllint "${imports[@]}" "${options[@]}" -- "${sources[@]}"
fi
if ((${#shortcut_sources[@]} > 0)); then
  qmllint "${imports[@]}" "${options[@]}" --import disable -- "${shortcut_sources[@]}"
fi
