#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(cd -- "$root/.." && pwd)

for repository in app-daemon bar-daemon bt-daemon clip-daemon nm-daemon; do
  if [[ ! -f "$projects/$repository/flake.nix" ]]; then
    echo "missing sibling checkout: $projects/$repository" >&2
    exit 2
  fi
done

# The resource presentation fixture is also daemon-owned, but remains separate
# from app-api v1 so it can describe every flattened presentation field.
app_out=$(nix build "$projects/app-daemon#default" --no-link --print-out-paths)
resource_actual=$(mktemp)
trap 'rm -f "$resource_actual"' EXIT
"$app_out/bin/app-daemon" debug resource-contract-fixture > "$resource_actual"
diff -u \
  <(jq -S . "$root/contracts/app-resource-ui-contract.fixture.json") \
  <(jq -S . "$resource_actual")

# Unlike the normal reproducible flake check, this intentionally evaluates the
# sibling worktrees (including uncommitted candidate changes). It is the
# cross-repository gate used before updating the release lock.
nix flake check "$root" --show-trace \
  --override-input app-daemon "path:$projects/app-daemon" \
  --override-input bar-daemon "path:$projects/bar-daemon" \
  --override-input bt-daemon "path:$projects/bt-daemon" \
  --override-input clip-daemon "path:$projects/clip-daemon" \
  --override-input nm-daemon "path:$projects/nm-daemon"
