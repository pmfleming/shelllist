# Test pruning — current baseline c6451f8 + working tree

## Baseline and result

The baseline includes **all incoming work**, including the preceding shared-chooser
Lens refactor and its tests, not just committed `c6451f8`. The matching full Qt
baseline is the immediately preceding successful run: 859 passes, zero failures,
one existing renderer skip. Its log and a fresh pre-pruning source archive,
working patch and hashes are in `target/test-pruning-c6451f8/`.

The unchanged `tests/count-test-inventory.py` counts JavaScript assertion sites,
Qt behavioral cases/data rows, Rust/Python tests and daemon contract suites.
Qt lifecycle hooks are excluded. The existing software-renderer skip is included
in inventory **but not executed coverage**. Manual captures, smoke/build scripts,
sibling repositories and loop iterations inside assertion helpers are not extra
inventory units. This established mixed inventory is not a coverage percentage.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion sites | 57 | 57 | 0 |
| Qt behavioral cases/data rows, including one existing skip | 736 | 469 | 267 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **808** | **541** | **267** |

`round(808 × 0.67) = 541`: **33.04% removed, 66.96% retained**.
Qt reports **859 → 592 passes**; both include 124 lifecycle hooks. All 62 suites
remain discovered. No counter changes, runner filters, new skips, renamed hidden
tests or packing of removed scenarios into loops. Existing parameterized tests
now enumerate fewer scenarios; each retained row is still counted independently.
Missing selected producer examples now fail instead of silently omitting a row.

Only 23 Qt test files and documentation changed in this pass. Production code,
Lens entrypoints, runners, build checks, native producer fixtures, JavaScript,
Rust and Python tests are unchanged from the incoming snapshot. In particular,
the incoming Bluetooth recovery and battery-control test changes are preserved.
Previous Lens validation remains a historical checkpoint, not current test count.

## Review decisions and retained coverage

### Contract matrices: partition by state owner, not method × every error

- **Notification actions:** retain request/acknowledgement checks for all eleven
  current operations, plus separate failed reply, DND, app-policy, prepare/delete
  and cancellation outcomes; stale action/record/snooze and validation rejection.
  Sample timeouts for drafts and consent; reconnect for settings, actions and
  replies. Keep newer-draft/reused-ID, event-before-ack and newer-DND-event races.
  Remove backend-only togglePanel/toggleDnd compatibility routes.
- **Bar session controls:** retain all thirteen request DTOs and authoritative
  results. Sample workspace/update failures, seek validation, selection failure
  and control-mode rejection. Playback/seek/selection/focus sample timeout or
  disconnect, rather than all twenty-six combinations. `SystemChoosers`,
  `BalancedDashboard` and `MediaChip` retain actual user routes and capability
  guards; shared daemon tests retain transport ownership.
- **Battery:** retain every command success, all three limited hardware readbacks,
  threshold/config failure, inhibition rejection and calibration readback failure.
  Keep threshold/protection/alert explicit retries, newer saved edits after both
  acknowledgement and timeout, cancellation-versus-completion, stale pushed state,
  status timeout, owner loss, and failed calibration restoration. Sample transport
  uncertainty by owner rather than repeating it for every command.
- **Audio/brightness/power profiles:** retain every request shape, clamped audio
  and brightness readbacks, degraded profile telemetry, brightness error OSD,
  rejected microphone change, action failure and battery-aware rejection. Both
  bar and battery owners retain reconnect/no-replay checks.
- **Sleep:** retain every request DTO, distinct lock/keep-awake/policy/critical
  error ownership, uncertain hibernation, and full suspend/hibernate lifecycles.
  All six terminal failure classes and all three reconnect stages remain, each
  sampled with one action instead of crossed with both. Critical cancellation
  still cannot undo dispatched sleep, and a lost cancel reply cannot replay.
- **Displays:** retain all six successful operations, preview rejection/failure,
  uncertain confirmation, failed revert, focus rejection and docking failure.
  Sample preview/confirm/policy reconnects. Keep authoritative rollback/expiry,
  failed rollback, external stale drafts and exactly-once close-time revert.
  The entire 25-case native `Displays` interaction suite is unchanged.
- **Activity and reads:** retain every Activity request success, read failure,
  create validation, deletion failure, create/complete/delete uncertainty and
  late success/error fences. All fourteen bar streams still execute push routing;
  sample gap recovery on three shapes instead of all streams. Dedicated
  `BarDomainRecovery`, `DaemonBridge`, `DaemonSessions`, work-area and compositor
  suites retain generation, monitor failure and independent recovery behavior.
  Remove duplicate metadata-envelope rejection (retained in shared boundary and
  Applications tests), resident snapshot (used by notification contract setup),
  and synthetic sleep naming checks (covered by live sleep/read fixtures).
- **Notification queries:** remove six compatibility-only history/list/app-view
  routes that no longer own a UI projection. Keep app/timeline native paging,
  group resolution, stale-cursor restart, old search/transport fences and sampled
  invalid/busy errors without read loops. Producer fixtures remain intact.

### UI duplication and presentation constraints

- Keep all twelve actual surface/controller/content construction routes. Sample
  environment deep links with eager, lazy and invalid IDs; shortcuts with default,
  eager and hyphenated lazy IDs. Keep registration/no-preload, unknown IDs and
  deferred latest-request ownership. Remove per-ID repetition and the two-registry
  metadata-isolation implementation test.
- Remove Resources' four size/theme/plot-style layouts and duplicate model-gap/
  recolouring test. Retain actual range save/discard, source updates during a
  draft, canonical totals, unavailable-versus-zero and app-owned passive metadata.
  `check-resource-availability.js` retains disjoint-series gaps and clipping.
- Remove battery sleep colours, the duplicate hardware width, history footer
  allocation and redundant visible-window opening fixture. Keep cold hidden-view
  activation, reopening and late-focus cancellation, field-local power/threshold/
  range transactions, real hardware-toggle dispatch, and safety confirmations.
  Remove palette/icon-table assertions from those retained behavioral workflows.
  Battery history retains signed power pixels/gaps in one theme/size, live theme
  repaint during inspection and unknown/zero/warning distinctions.
- Sample compact confirmations at one narrow size, and pairing by consent,
  validated passkey and remote-owned display. PIN clearing/queue/reply identity
  stay in unchanged `BluetoothRecovery`. Keep connected Wi-Fi's typed destructive
  challenge and credential opt-out; remove its duplicate inactive presentation.
- Remove notification title/pluralization permutations, exact switch-label geometry,
  result-fade geometry, centered application empty icons and excess icon candidate
  tables. Keep malformed deletion counts, app/record scopes, consent cancellation,
  late preparation, actual icon-load failure/recovery, symbolic fallback and
  internal-content exclusion. Shared text contrast and all 150 JS palette cases
  remain. Shared overflow/menu, field, chooser-memory and native secret tests are
  unchanged. Failed-save, lease, clipboard privacy and Wi-Fi recovery suites remain.
- Applications retain producer success/failure without polling and duplicate-event
  guards, dropping cancelled duplication and the legacy nested envelope. Sample
  catalog errors with unavailable and validation failures, not seven error strings.
  Existing handoff, uncertain Close, late completion and owned recovery cases stay.

## Changed Qt suites

Counts include data rows and the existing skip, not lifecycle hooks.

| Suite | Before | After |
| --- | ---: | ---: |
| NotificationActionContract | 69 | 31 |
| BarSessionControlContract | 64 | 22 |
| BatteryContract | 54 | 27 |
| BarControlContract | 49 | 21 |
| SleepContract | 44 | 27 |
| DisplayContract | 34 | 19 |
| ActivityContract | 29 | 15 |
| BarReadContract | 36 | 23 |
| SurfaceRegistry | 30 | 19 |
| SurfaceShortcuts | 13 | 4 |
| NotificationQueryContract | 15 | 7 |
| ApplicationResources | 8 | 3 |
| BatteryPresentation | 15 | 9 |
| CompactConfirmations | 14 | 6 |
| NotificationCenter | 21 | 16 |
| SharedPanelComposition | 4 | 1 |
| NotificationIcons | 10 | 3 |
| ResultListReactivation | 2 | 1 |
| ApplicationDetails | 4 | 3 |
| ApplicationContract | 11 | 6 |
| ApplicationActions | 19 | 17 |
| BatteryHistory | 4 | 3 |
| BatterySuspend | 3 | 2 |

## Deliberate coverage gaps

This does not establish identical branch coverage. Individual command × error ×
transport combinations have less direct evidence; shared handlers do not prove
all endpoint wiring. There is less native coverage for exact chart layout/palette,
short Resources scrolling, long switch labels, battery history's footer placement,
standalone visible-window activation, icon candidate ordering, alternate pairing
presentations, inactive Wi-Fi confirmation, per-surface startup/shortcut routes,
notification wording, cancelled application push outcomes and removed compatibility
APIs. These are deliberate tradeoffs, not waived product or safety contracts.
Native fixture data and separate daemon contract checks still describe the full
producer API. Add focused regressions when needed; **541 is not a permanent cap**.

## Validation and reproduction

Passed: full Qt **592 passes, zero failures, one unchanged renderer skip**;
strict QML lint; all 16 behavioral JavaScript scripts plus source-tree imports;
two Python tests; four Rust search tests; timezone build/test (zero unit tests);
native offscreen runtime smoke (existing unsupported-window-mask warning).

The four retained portal-launcher Rust tests could not run with `--offline
--locked`: Cargo requires a lockfile update against the local sibling dependency.
Its manifest/lock and all Rust tests are unchanged from the baseline; no lockfile
was rewritten or gate relaxed. The five daemon contract suites were retained but
not rerun. No full sibling-aware Nix/package, hardware, RHI, IME or screen-reader
acceptance is claimed. An intermediate Qt run exposed a removed *required*
fixture `uiScale`; it was restored as `1`, and all three retained Resources cases
pass in the complete final run. No failing case was deleted to obtain the result.

```sh
QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh > /tmp/pruned-qml.log 2>&1
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
tests/run-qmllint.sh
bash tests/run-runtime-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
# Node arguments are in flake.nix; executed script is saved with local evidence.
cargo test --offline --locked --manifest-path rust/shelllist-search/Cargo.toml
cargo test --offline --locked --manifest-path portal-launcher/Cargo.toml
```

Local evidence: `before-source.tar`, `final-source.tar`, `incoming.patch`,
`pruning.patch`, `incoming-hashes.json`, `preservation.json`, `before-qml.log`,
`before.json`, `final-qml.log`, `final.json`, `comparison.json`, `case-diff.json`,
`run-javascript.sh`, `lint.log`, `javascript.log`, `python.log`, `rust.log`,
`timezone.log`, `smoke.log`
under `target/test-pruning-c6451f8/`. The initial post-edit failure is retained in
`after-qml.log`; it is not passing evidence. Counts and source preservation were
checked against the saved baseline, not historical pruning documents.
