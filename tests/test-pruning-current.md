# Test pruning — baseline aefcf52

## Baseline, target and result

The baseline is `aefcf52` plus the incoming working-tree changes to two bar
contract files and `tst_bluetooth_recovery.qml`. Those changes are preserved.
`target/test-pruning-aefcf52/` contains the starting source archive, incoming
patches, matching full Qt logs, inventories and validation logs. The pruning
commit excludes those incoming changes, including the Bluetooth readiness fix.

The existing `count-test-inventory.py` is unchanged. It counts JavaScript
assertion sites, Qt behavioral cases (including individual data rows), Rust and
Python tests, and daemon contract suites. It excludes Qt lifecycle hooks and
includes the explicitly identified existing renderer skip, **not as executed
coverage**. Manual captures, smoke/build checks and sibling repositories are not
additional inventory units. These are mixed units, not independent scenarios or
a coverage percentage; the same scope and counter measure both snapshots.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion sites | 76 | 57 | 19 |
| Qt behavioral cases/data rows, including one existing skip | 339 | 216 | 123 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **430** | **288** | **142** |

`round(430 × 0.67) = 288`: **33.02% removed, 66.98% retained**.
Qt reports **436 → 311 passes**, with **98 → 96 lifecycle hooks** excluded
from inventory and the same single software-renderer skip in both runs.
The baseline passed before any deletion; no failing test was removed to obtain
a passing result.

These are actual case/site removals, not renamed helpers, packed assertion
tables, discovery exclusions or newly skipped tests. The only deleted suite is
`PanelRoles`; its unused fixtures disappear with it. Test runners, inventory
rules, Lens configuration, build checks and production code are unchanged.
A few unique guard assertions are retained in existing related workflows rather
than carrying an otherwise duplicate fixture.

## Decisions and coverage owners

- **Transport:** remove 16 JavaScript assertion sites duplicating native
  `DaemonBridge` close/reopen, startup, repeated-close, unexpected-exit and failed
  drain workflows. Keep all seven native cases, including close from a readiness
  callback. JavaScript still owns startup failure/no replay, the backoff/exit
  race, envelope/gap validation, subscription cancellation, detached and stale
  generations, routed events and bounded startup buffering. The brittle
  source-extraction duplicate is removed rather than weakening native behavior.
- **Presentation:** remove exact palette, typography, icon-table, card-inset,
  plot-style, field-family alignment, Weather-size and status-background tests.
  Shared `FieldInteraction` remains unchanged (17 cases); `ActionControl`,
  `MaterialFields`, `CompactFields` and the native field-contrast test remain.
  The overlong-status readable fallback remains, as do all 150 JavaScript
  seed/theme contrast combinations. Remove the unused inline `BarTrayItem`
  fixture; current Tray chooser identity and native-menu lifetime tests remain.
- **Applications:** sample Close closed/missing outcomes and failed placement
  instead of all status permutations. Keep real focus/launch handoff,
  admission-versus-acknowledgement, still-open windows, command removal,
  concurrent targets, reopening, owned automatic status recovery, malformed
  reads, transport loss and no replay. Keep stable window IDs and arbitrary
  desktop commands. Resources keeps field transactions, arriving snapshots,
  canonical totals, unavailable versus zero and application-owned metadata.
  Its retained range test checks that stale plots disappear while current
  readings survive. Pure-model numeric, interval and availability checks remain.
- **Battery/Bluetooth:** remove theme duplicates and decorative command tests,
  retaining calibration/critical-policy confirmation, target replacement,
  degraded telemetry, countdown/unknown outcomes and acknowledged settings.
  Bluetooth samples malformed adapter values/disconnect and missing audio
  outcomes; native partial success, captured adapter identity, fresh saves,
  rename failure/recreation, pairing queue/response identity and secret clearing
  remain. Remove repeated timeout-widget key sequences; shared sliders and the
  adapter batch's timeout payload/partial retry still execute. Remove three
  Bluetooth status-wording/pluralization assertion sites, not visibility policy.
- **Clipboard:** sample Tab lease submission, Enter retry, fresh/failed Escape
  discard, Escape confirmation cancellation and Tab/Return deletion. Preserve
  failed drafts, original revision/fresh lease, conflicts, disconnect recovery,
  all three save-and-paste outcomes, native search/paging and explicit retry.
  Remove cache capacity/eviction internals and one image reply-order row;
  retain stale revision/thumbnail, privacy, hidden invocation and warm-cache
  behavior. Failed-draft precedence is asserted during the retained warm-cache
  revisit instead of inside the deleted eviction fixture. Repeated button
  alignment/activation routes are removed, not the confirmation safety boundary.
- **Displays:** retain opaque mode IDs, local layout saves, native Preview token,
  Keep/Revert acknowledgement, last-active-screen protection, mirror promotion,
  actual placement/drag/cancel, collision guards, dirty close confirmation,
  hardware-delayed docking, manual/same-preference recovery, independent
  capabilities, stale topology, expiry and late-preview rollback. Sample
  enable/keep versus disable/revert rather than the output × input × outcome
  matrix. Remove per-field duplicate save/discard, focus-widget binding and
  countdown sizing fixtures; shared binding transactions and the acknowledged
  global focus workflow remain. The short viewport fixture still exercises the
  transition from extended to docked.
- **Notifications:** reduce malformed shape/count and unowned-context matrices
  to representative payload and ownership failures. Keep record-scoped and
  app-scoped deletion, cancellation/no replay, late preparation, policy save
  failure, DND/reply acknowledgement, connection generations, atomic app/timeline
  publication, queued revisions, native search, stale cursors, duplicate records,
  local-midnight fences, period navigation and bounded rendering. Remove old
  Message-tab absence tests, exact text/icon hierarchy, per-app viewport and
  repeated refresh abandonment fixtures. Timeline viewport restoration and
  shared model/progressive-selection tests remain. Actual failed icon load and
  recovery remain, without the source-priority/icon-name table.
- **Wi-Fi/media:** remove duplicate power-conflict/cancellation fixtures,
  retaining the power guard inside the real QR workflow and a foreign-cancel
  check inside keyboard cancellation. Status failure, bounded polling, missed
  completion, disconnect/no replay, QR secret non-retention and native prompts
  remain. Portal retains prepare/claim/complete, expiry/URL mismatch, unowned
  responses, reconnect, suppressed automatic launch, process failure and
  explicit Sign in. Media retains explicit inspected-player routes,
  acknowledgement, capability/busy/disconnected guards, settings and native
  Tray ownership. Disappeared-player rejection is retained in the actual Enter
  workflow instead of a second controller-only fixture. Artwork loading and
  passive enrichment still execute in MediaChip/MediaSources.

## Changed Qt suites

Unlisted suites are unchanged. Counts include data rows, not lifecycle hooks.

| Suite | Before | After |
| --- | ---: | ---: |
| ApplicationActions | 23 | 13 |
| ApplicationResources | 11 | 3 |
| BalancedDashboard | 13 | 4 |
| MaterialBar | 3 | 2 |
| BatteryPresentation | 8 | 4 |
| BatterySuspend | 5 | 3 |
| BluetoothRecovery | 28 | 17 |
| ClipboardPreview | 9 | 6 |
| ClipboardRecovery | 21 | 14 |
| Displays | 43 | 24 |
| NotificationCenter | 33 | 14 |
| NotificationIcons | 5 | 1 |
| Notifications | 24 | 13 |
| PanelRoles | 5 | 0 |
| SharedPanelComposition | 3 | 1 |
| SurfaceActions | 4 | 2 |
| SystemChoosers | 8 | 5 |
| WifiOperations | 14 | 12 |
| WifiPortal | 11 | 10 |

## Deliberate coverage gaps

This does **not** prove identical branch coverage. There is less direct evidence
for exact geometry/paint, switch-label wrapping, heading Help wiring, resource
chart rendering, positive battery fill levels, icon precedence, whole-bar overflow,
all action outcome variants, individual display focus-number/timeout widgets,
cache eviction budgets, both image reply orders, all malformed response shapes,
all notification ownership dimensions, app-list viewport restoration, mid-refresh
app epoch/hide cases and claim-denial manual retry. Media-card cross-player artwork
and light-theme metadata contrast no longer have a dedicated consumer fixture.

Shared tests are not proof of every consumer's wiring. In particular, native
field binding tests do not directly exercise the removed display numeric Apply
button or adapter timeout editors. Core safety tests took priority over those
consumer permutations. Historical UI documents describe broader evidence at their
original checkpoints, not current coverage. Add focused regressions when these
boundaries produce meaningful failures; 288 is a checkpoint, not a permanent cap.

## Validation and reproduction

Passed: full Qt suite (**311 passes, zero failures, one unchanged skip**), all
16 behavioral JavaScript scripts plus source-tree import checking, eight Rust
tests, two Python tests, strict QML lint and native offscreen runtime smoke.
The five daemon contract suites are unchanged and **were not rerun**. Full
sibling-aware Nix/package evaluation, RHI, hardware, IME and screen-reader
acceptance were not performed. The existing offscreen window-mask warning is
not a failed assertion.

```sh
tests/run-qml-tests.sh > /tmp/pruned-qml.log 2>&1
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
# Node arguments: flake.nix; local executed script: target/test-pruning-aefcf52/run-javascript.sh
cargo test --offline --locked --manifest-path rust/shelllist-search/Cargo.toml
cargo test --offline --locked --manifest-path portal-launcher/Cargo.toml
CARGO_TARGET_DIR="$PWD/target/timezone-test" cargo test --offline --locked \
  --manifest-path rust/shelllist-timezone-assets/Cargo.toml
```

Cargo/rustc 1.95.0 were supplied from the installed Nix store; no dependency or
lockfile update was needed. Timezone assets has zero unit tests. Matching local
artifacts are `before-qml.log`, `before.json`, `final-qml.log`,
`final-inventory.json`, `comparison.json`, `javascript.log`, `rust.log`,
`python.log`, `lint.log` and `smoke.log`. Do not reuse artifacts from an earlier
pruning directory as this baseline.
