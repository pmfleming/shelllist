#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
projects=$(cd -- "$root/.." && pwd)

for repository in daemon-framework shelllist-hyprland app-daemon bar-daemon bt-daemon clip-daemon nm-daemon; do
  if [[ ! -f "$projects/$repository/flake.nix" ]]; then
    echo "missing sibling checkout: $projects/$repository" >&2
    exit 2
  fi
done

# app-daemon deliberately vendors the framework. A candidate matrix using the
# sibling bridge everywhere else must not silently test an older app bridge.
if ! diff -qr "$projects/daemon-framework/crates" "$projects/app-daemon/vendor/daemon-framework/crates"; then
  echo "app-daemon's vendored framework differs from the candidate; refresh the snapshot first" >&2
  exit 1
fi

diff -q "$projects/shelllist-hyprland/Cargo.toml" "$projects/app-daemon/vendor/shelllist-hyprland/Cargo.toml"
diff -qr "$projects/shelllist-hyprland/src" "$projects/app-daemon/vendor/shelllist-hyprland/src"

# Both native search callers must use the exact same pure ranking algorithm.
diff -q "$projects/shelllist/rust/shelllist-search/Cargo.toml" "$projects/clip-daemon/vendor/shelllist-search/Cargo.toml"
diff -qr "$projects/shelllist/rust/shelllist-search/src" "$projects/clip-daemon/vendor/shelllist-search/src"

# The resource presentation fixture is also daemon-owned, but remains separate
# from app-api v1 so it can describe every flattened presentation field.
app_out=$(nix build "$projects/app-daemon#default" --no-link --print-out-paths --no-write-lock-file)
resource_actual=$(mktemp)
trap 'rm -f "$resource_actual"' EXIT
"$app_out/bin/app-daemon" debug resource-contract-fixture > "$resource_actual"
diff -u \
  <(jq -S . "$root/contracts/app-resource-ui-contract.fixture.json") \
  <(jq -S . "$resource_actual")

# Unlike the normal reproducible flake check, this intentionally evaluates the
# sibling worktrees (including uncommitted changes to tracked files; git-add new
# source files first). Git URLs exclude ignored Cargo targets and .git internals:
# path: inputs would hash/copy tens of GiB of build products into each candidate.
# This is the cross-repository gate used before updating the release lock.
nix flake check "$root" --show-trace --keep-going --no-write-lock-file \
  --override-input daemon-framework "git+file://$projects/daemon-framework" \
  --override-input shelllist-hyprland "git+file://$projects/shelllist-hyprland" \
  --override-input app-daemon "git+file://$projects/app-daemon" \
  --override-input bar-daemon "git+file://$projects/bar-daemon" \
  --override-input bt-daemon "git+file://$projects/bt-daemon" \
  --override-input clip-daemon "git+file://$projects/clip-daemon" \
  --override-input nm-daemon "git+file://$projects/nm-daemon"
