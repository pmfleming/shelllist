#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
runner=$(readlink -f "$(command -v qmltestrunner)")
qt_declarative_root=$(cd "$(dirname "$runner")/.." && pwd)

QT_QPA_PLATFORM=offscreen qmltestrunner \
  -input "$repo_root/tests/qml" \
  -import "$repo_root/qml" \
  -import "$qt_declarative_root/lib/qt-6/qml" \
  -o -,txt
