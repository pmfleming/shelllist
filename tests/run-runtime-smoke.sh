#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export QML2_IMPORT_PATH="$repo_root/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=offscreen
export WAYLAND_DISPLAY=

exec quickshell --no-color --path "$repo_root/tests/qml/smoke_shared_ui.qml"
