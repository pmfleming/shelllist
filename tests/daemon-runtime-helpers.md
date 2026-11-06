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
