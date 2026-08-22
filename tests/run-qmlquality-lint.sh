#!/usr/bin/env bash
set -euo pipefail

qt_root=$(cd "$(dirname "$(readlink -f "$(command -v qmllint)")")/.." && pwd)
quickshell_root=$(cd "$(dirname "$(readlink -f "$(command -v quickshell)")")/.." && pwd)

exec qmllint \
  -I "$qt_root/lib/qt-6/qml" \
  -I "$quickshell_root/lib/qt-6/qml" \
  "$@"
