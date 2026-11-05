# Workspace number shortcuts and manual retention

The ID-based numeric binding behavior below is historical. Positional shortcuts
now follow the monitor's bar order; see [current evidence](workspace-bar-positions.md)
and the [workspace contract](../contracts/temporary-workspaces.md).

2026-11-03. Investigation found two independent causes:

- `/etc/nixos/config/hypr/hyprland.lua` registered focus and move shortcuts only
  for workspace IDs 1–5. Read-only inspection of the running compositor confirmed
  no numeric bindings for 6–9 or 0. Both shortcut families now cover IDs 1–10,
  with 0 selecting 10. Higher IDs use the strip or previous/next commands.
- `bar-daemon/src/workspace/mod.rs::cleanup` intentionally retired an unused
  landing pad after switching away and a populated manual workspace when its
  last window left. The original lifetime contract required that behavior;
  the user's explicit-close requirement supersedes it for manual workspaces.

Committed source family: bar-daemon `85660da`, app-daemon test journey
`97c60fb`, and NixOS bindings/tests `c8c9c89`. Shelllist contracts and evidence
are committed together with this document.

Manual destinations now retain their ID/generation and strip entry until a
workspace close, including after Hyprland reclaims an empty inactive object.
Native focus and move rematerialize that same destination. The daemon also
accepts launch leases into a retained local destination that is absent from the
compositor snapshot. Launch-owned temporary workspaces keep automatic cleanup;
externally created workspaces keep compositor lifetime rules.

The additive private journal flag defaults false. Old live manual entries migrate
from their original reservation/generation; already admitted closes remain
revoked. Retention and landing-pad adoption are cleared durably with close
admission before any window close. Cleanup cannot readopt a pending empty close.
Allocation, lease fencing, request lookup and guarded normal window close remain
in the serialized Rust owner.

Regression coverage:

- Native Lua registration checks assert all ten focus/move pairs, exact target
  IDs and follow behavior, all four lifecycle commands, no command repeat,
  unchanged Super+Q and duplicate-key detection.
- Rust owner tests cover a manual workspace switching away, disappearing from
  the compositor snapshot, retaining its strip entry/generation across restart,
  accepting a new placement lease, becoming empty after population, and explicit
  close. Separate cases cover old-journal migration and pending-close readoption.
- The existing real-daemon private-compositor journey now checks native focus
  and move into a manual destination, retention after switching away and moving
  the window out, and explicit empty-workspace close, alongside its existing
  launch/restart/no-replay/late-window and optional Qt close-veto coverage.

Validation:

- Native Lua registration checks: passed against the rendered updated config.
- Rust library suite: 312 passed, zero failures, six existing opt-in skips;
  all 13 workspace cases passed.
- Full Rust all-target suite: 345 passed, zero failures, eight existing skips
  (library, CLI and integration targets). Log:
  `/tmp/workspace-retention-validation.log`.
- Strict all-target bar Clippy and focused app journey Clippy: passed. App
  formatting check passed; log: `/tmp/workspace-retention-journey-lint.log`.
- Bar formatting, all-target `cargo check` and warning-free `cargo doc
  --no-deps`: passed. The private journey used the updated bar binary produced
  by the all-target test build; no release or Nix package deployment is claimed.
- Private compositor journey: one passed with the Qt close-veto branch enabled.
  It observed successful manual focus/move, retained empty strip entries,
  explicit manual retirement and `still-open` for the refusing Qt client/dialog.
  Installed Hyprland: 0.56.2, `efb50993780079460b0cbed1363e2166a2de1d9f`.
  Evidence directory: `/tmp/wsj-8KjE2I`; log:
  `/tmp/workspace-retention-native.log`.

Build and test commands use the pinned Nix development shells with
`--no-write-lock-file`, retaining the current sibling Rust path dependencies.
No production service restart, compositor reload or host activation is part of
these checks. Numeric binding assertions test registration and arguments; the
private compositor journey executes the matching native dispatcher operations,
not physical keyboard delivery on the production desktop.
