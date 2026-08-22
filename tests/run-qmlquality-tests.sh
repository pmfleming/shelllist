#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
runner=$(readlink -f "$(command -v qmltestrunner)")
qt_root=$(cd "$(dirname "$runner")/.." && pwd)

exec qmltestrunner \
  -input "$repo_root/tests/qml" \
  -import "$repo_root/qml" \
  -import "$qt_root/lib/qt-6/qml" \
  "$@"
