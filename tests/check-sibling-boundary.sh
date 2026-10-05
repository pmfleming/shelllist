#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(cd -- "$root/.." && pwd)

# CO-DEVELOPMENT INVARIANT: snapshot every tracked worktree once, then run the
# complete framework/daemon/UI matrix against that graph. Never compare against
# vendored framework copies or fall back to historical flake.lock revisions.
exec "$projects/daemon-framework/tools/local-build" check "$root" \
  --show-trace --keep-going
