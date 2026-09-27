#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export QML2_IMPORT_PATH="$repo_root/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=offscreen
export WAYLAND_DISPLAY=
# Native window smoke must never dispatch rules to a live compositor.
unset HYPRLAND_INSTANCE_SIGNATURE
export SHELLLIST_MODE=floating

quickshell --no-color --path "$repo_root/tests/qml/smoke_shared_ui.qml"
exec quickshell --no-color --path "$repo_root/tests/qml/smoke_chooser_geometry.qml"
