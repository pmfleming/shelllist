# Runtime helper migration evidence

## Search

- Shared matcher: six tests pass, including frozen scoring parity and prepared
  catalog reuse; two manual performance probes remain ignored. All-target Clippy
  for the matcher passes with warnings denied.
- Bar search: the private Unix-socket test passes for Unicode/fractional ranking,
  revisions, idempotent retransmission, conflicting replacement, caller isolation,
  explicit release, item limits and disconnect cleanup.
- The production direct-socket/D-Bus parity test passes with catalog/query/release
  added to the same transport fixture. The producer contract fixture was refreshed
  by its Rust test and the Shelllist contract/registry parity check passes.
- Actual Qt search lifecycle tests: four passes. Full Qt run after domain-fixture
  isolation: 731 passes, one failure and one existing renderer skip. That remaining
  failure was an unrelated transient null `cardColumn` binding in
  `ApplicationActions::test_appDataHasOneHomeOnTheSettingsTab`; the exact test
  passes on an isolated rerun. Chooser keyboard/memory and all four assertions
  previously affected by shared search traffic pass in the full rerun.
- Search singleton strict QML lint passes. Panel numeric-role review has zero
  changed-line or new-wrapper prompts. Build-input audit unit tests: six passes.
  Bar library Clippy also passes with warnings denied.

The live sibling build-input audit currently encounters concurrent bar workspace
extractions outside this migration (four new manifests plus their shared
`chrono-tz`/`tzf-rs` dependency inventory). This is separate from search ownership.
No desktop services, focus, browser or hardware configuration were changed by
these checks. Live compositor acceptance remains separate from offscreen Qt.

## Portal executable

- The moved `nm-portal-launch` binary's five native tests pass unchanged in NM's
  dependency graph. They cover literal browser arguments, bounded URL/workspace
  and deadline handling, untrusted compositor addresses, named workspaces and
  actual mock Unix-socket move/focus dispatch. Binary Clippy passes with warnings
  denied.
- The five NM portal policy/ledger tests pass, including owner/expiry/network
  fences, fail-closed persistence and no replay after lost replies or restarts.
- Actual Qt portal interaction tests: seven passes, including the new assertion
  for the exact NM-owned executable/URL/workspace/deadline after claim. Existing
  no-launch-on-navigation, Alt+I, changed claims, recovery and uncertain outcomes
  remain covered. Wi-Fi backend strict QML lint passes; the panel-role review
  reports zero numeric or new-wrapper prompts.
- The real Quickshell 0.3.2 application journey passes with the new bar-backed
  ranking transport, exercising search, settings acknowledgement, failed launch,
  explicit retry and restored persistence against a packaged app backend.
- Source, browser-profile/window-class identifiers and argument/outcome behavior
  are preserved. The only Rust source edit changes the ownership module comment;
  the executable name and its package/source/lock ownership change together.
- The NM Nix package builds successfully from the tracked local NM/framework
  snapshot. Its installed `nm-portal-launch` exists and rejects an invalid URL
  with the expected JSON `failed` outcome before any browser/compositor effect.
  The package test phase includes the moved executable's tests.
- Both changed Nix files parse. All 17 xtask unit tests and three CLI tests pass.
  The broader Shelllist snapshot gate remains blocked by unrelated untracked
  bar power-daemon files from the concurrent extraction, and the build-input
  audit still needs that extraction's manifest/dependency inventory update.
