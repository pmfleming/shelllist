# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer one representative scenario or a labeled table over repeated
fixtures for the same behavior.

## Coverage to retain

- Daemon protocol fixtures and generated bindings, including request/event
  correlation and incompatible-envelope rejection.
- Shared-session recovery, late subscription replies, owner-scoped cancellation,
  response-before-event ordering, deadlines, and idle-listener survival.
- Secret handling, path confinement, private persistence, image allocation limits,
  stale revisions, and validation before destructive operations.
- Provider dispatch, asynchronous ranking, selection restoration, and domain
  lifecycle/presentation behavior.

## Coverage deliberately pruned

- Source-token checks that prescribe helper names, component composition, exact
  debounce durations, or obsolete migration structure.
- Trivial lookup/default/serialization helpers already exercised through broader
  behavior or protocol tests; tests of fake implementations rather than consumers.
- Duplicate happy paths and old storage-format/fallback-layout expectations that
  are not current compatibility requirements.

Closely related cases share fixtures where useful: error classification, network
health traces, profile updates, Bluetooth identity reloads, clipboard classification,
notification persistence, and battery history retention. Security and failure cases
remain explicit. Screenshot size limits are checked through the clipboard API, not
just its private validator. Timezone assets retain their generated-asset check rather
than hard-coded region counts or QML implementation assertions.

## Frontend pruning inventory

This pass removes checks rather than renaming or combining test functions to make
runner totals smaller. Shelllist mixes ad-hoc JavaScript scripts with QtTest and
Rust, so there is no single framework-reported test count:

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript behavioral check sites | 566 | 372 |
| Executed QML cases, including data rows | 89 | 66 |
| Rust test functions | 4 | 4 |
| Daemon contract suites | 5 | 5 |
| **Total inventory units** | **664** | **447** |

That is a **32.7% reduction** in the combined inventory, not a coverage percentage.
JavaScript counts assertion/helper calls and script-level failure guards, excluding
fixture/helper bodies and CLI usage guards; loops/tables count once per check site,
not once per iteration. QML counts exclude setup/cleanup. One Bluetooth case was
added concurrently and is included in the final count. Build, lint, performance,
module-evaluation and packaging gates are retained but not counted as test cases.

The main removals and remaining owners are:

- Exact glyph/label tables, full per-device artwork mappings, bar module indices,
  and exhaustive responsive breakpoints. Keep semantic distinctions, actual
  action routing, representative asset existence, and narrow-screen reachability.
- Legacy Wi-Fi flag inference and remembered-earbud layout assumptions. Current
  daemon classifications and reported component topology remain covered. Both
  supported Hyprland dispatch syntaxes remain tested; they are not obsolete.
- Repeated selection-position × refresh-timing combinations and a duplicate
  progressive-population test. The visible-list regression still covers both
  refresh orderings, later-page population, and intentional user scrolling.
- Duplicate notification merge/filter/reply presentation checks and fixed toolbar
  layout assertions. Keep multi-page catch-up, reused notification IDs, reply
  acknowledgement/failure, focused drafts during live updates, DND policy and
  controls staying reachable as the agenda shrinks.
- Direct geometry helper/event-name enumerations. Keep fractional/rotated/offset
  screens, changing reservations, workspace rules, malformed snapshots, width
  clamping and the Time & Weather inheritance regression.
- Source-token architecture assertions. Failed transport generations now execute
  the real queue lifecycle; incompatible events and gaps go through the backend.
  Clipboard annotation survival and revision-checked bulk deletion execute the
  controller/backend methods instead of matching source patterns. Shared-session
  recovery and late subscription cancellation remain unchanged.

No daemon fixture, protocol version, lock, production implementation, security
validation, or destructive-operation guard was relaxed to achieve the reduction.

## Validation

Run `nix flake check --no-update-lock-file` in Shelllist and the shared framework.
The Shelllist checks include QML tests, JavaScript behavior, generated assets and
bindings, protocol contracts, lint, packaging, and runtime smoke coverage.

In each Rust repository, use its declared development environment:

```sh
nix develop --no-update-lock-file --command cargo test --offline
nix develop --no-update-lock-file --command cargo clippy --offline --all-targets -- -D warnings
nix develop --no-update-lock-file --command cargo fmt --all --check
```

Locked integration and candidate sibling-worktree integration are different checks;
do not update fixtures or locks merely to make a test-pruning change pass.
