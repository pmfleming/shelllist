# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables or freeze visual choices unnecessarily.

## Retained coverage

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG plugins and timezone data. Both QML
runner scripts use the same offscreen/software, UTC setup. Refresh an existing
development shell after changing `flake.nix`.

- `tst_field_interaction.qml`: local drafts, binding survival, backend updates
  during editing, native arrows and slider Home, forward/reverse Tab after
  availability changes or removal, editable-only traversal, switch safety,
  pointer transactions, continuous-preview rollback and command menus.
- `tst_chooser_keyboard.qml`, `tst_chooser_memory.qml` and
  `tst_domain_workflows.qml`: search/result navigation, asynchronous restoration,
  newer-navigation/closure fences, per-result memory, value-free restoration,
  missing/sensitive editor targets and modal containment. Application suites own
  acknowledgement; notification/model suites retain keyed viewport coverage.
- `tst_displays.qml`: representative keyboard/drag placement, cancellation,
  unsafe layout guards, opaque modes, local drafts, trial ownership, late/hidden
  Preview reversion, docking acknowledgement/retry and focus-policy safety gates.
  JavaScript covers all placement directions and rotated fractional layouts.
- Shared controls retain keyboard, pointer and assistive activation, busy/disabled
  guards, native masking/reveal, read-only editing, dropdown acknowledgement and
  cancellation, command availability, passive labels and close-time reordering.
  Representative painted field contrast remains; exhaustive wrapper/header
  geometry and palette-token snapshots do not.
- Bluetooth, Clipboard, Battery, Notifications and Wi-Fi retain domain
  acknowledgement, failed-save drafts, retries, stale identities/replies, leases,
  secret clearing, uncertain outcomes and destructive-operation guards. System
  choosers retain explicit media targets, capability checks, acknowledged settings
  and native tray-menu lifetime. Media artwork clearing, plain-text metadata and
  passive enrichment remain.
- `tst_balanced_dashboard.qml` covers stable category identity, acknowledged
  workspace activation and unavailable versus zero battery readings.
  `tst_media_chip.qml` samples narrow seek transport and keeps missing-player
  controls visible but disabled; system choosers exercise panel transport. Its RHI-only artwork pixel check
  remains an explicit existing skip under the software runner.
- Daemon/session and model suites retain protocol/generation boundaries,
  request churn, stable identities, queued-update cancellation and
  progressive/native list updates. Wi-Fi retains cancellation acknowledgement.
  Notifications retain atomic center refresh, obsolete-read rejection and live reply focus through a
  205-record burst.
- JavaScript retains unsafe-layout/numeric validation, unavailable versus measured
  zero, chart gaps, history/cursor failures, request identity, no-replay rules and
  battery safety. Material contrast covers 150 seed/mode combinations. Native
  QML checks actual field pixels and SVG decoding. Runtime smoke exercises native
  offscreen windows and chooser geometry; `tst_work_area.qml` covers authoritative
  geometry and failure recovery.

Expected negative-test application error logs are distinct from QML engine
warnings and remain allowed. Offscreen tests do not replace live compositor,
hardware, IME or screen-reader acceptance.

## Current working-tree pruning checkpoint

Baseline includes the incoming uncommitted changes, not an older commit.
**365 → 245 inventory units: 120 removed (32.88%), 67.12% retained.**
This is the nearest-integer 67% target under the existing mixed counter.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 55 | 55 |
| QML behavioral cases, including data rows and one existing skip | 295 | 175 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **365** | **245** |

All 120 reductions are actual Qt case removals, not renames, new skips, assertion
repacking or discovery exclusions. Five redundant suites and their unused
fixtures were removed; Lens loses only the deleted notification-actions
entrypoint. A few unique safety assertions moved into retained workflows.
Production code, the counter, runner and JavaScript/native tests were not changed
by this pass. Existing unrelated worktree and staged changes were left intact.

Validation: **258 Qt passes, zero failures, one existing renderer skip**
(174 executed behaviors + 84 lifecycle hooks), all 16 behavioral JavaScript
scripts, eight Rust tests, two Python tests, QML lint and native runtime smoke.
The five daemon contract suites remain unchanged and were not rerun; no full Nix
or hardware/RHI gate is claimed. This mixed count is not a coverage percentage.

See [decisions and coverage trade-offs](test-pruning-current.md). Matching baseline
and final logs are in ignored `target/test-pruning-current/` (`before-qml.log`,
`final-qml.log`, `before.json`, `final-inventory.json`). Earlier files in that
artifact directory describe previous passes and must not be mixed with these.
This target is a checkpoint, not a permanent cap on useful regression tests.

## Previous pruning checkpoint — 2026-10-07

Baseline: refactor commit `416bd9e`, with unrelated incoming changes preserved.
Nearest-integer 67% target: **464 → 311 inventory units** (**32.97% removed;
67.03% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 90 | 54 |
| QML behavioral cases, including data rows and one existing skip | 359 | 242 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **464** | **311** |

This established mixed inventory is **not independent scenarios or a coverage
percentage**. There are genuinely **117 fewer Qt cases**; the 36 fewer JavaScript
sites mostly consolidate related checks into labeled tables, retaining numeric
validation/interval cases while removing presentation assertions covered by Qt.
No tests were newly skipped, hidden in renamed helpers or excluded from discovery.
All suites and Lens entrypoints remain. Native transaction, domain safety,
protocol, retry and no-replay coverage takes priority over visual matrices,
per-wrapper geometry, exact icon tables and duplicate happy-path workflows.

Final validation: **331 Qt passes, zero failures, one unchanged renderer skip**
(241 executed behaviors + 90 hooks), all 16 JavaScript scripts, strict lint,
runtime smoke, TypeScript generation/typechecking, eight Rust and two Python tests
pass. All five daemon contracts remain unchanged but were not executed; no full
Nix gate was run. An RHI probe failed pixel checks on this host and is not claimed
as acceptance. See the [review](../docs/reviews/test-pruning-2026-10-07.md) for
explicit coverage gaps, the baseline renderer evidence and reproduction commands.
Local artifacts: `target/test-pruning-2026-10-07/`.

The inventory counter still rejects failures, unexpected skips and incomplete
logs. Count the pre-existing software-renderer skip explicitly in both snapshots:

```sh
python3 tests/count-test-inventory.py --qml-log <matching-run.log> \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
```

The skipped case remains counted but is **not executed coverage**. This explicit
accounting option does not skip anything or change the test runner. Without the
option, skips still fail inventory validation. These counts are not a permanent
cap; add focused regressions for meaningful failures.

## Previous pruning checkpoint — 2026-10-06

Baseline: `8f47572` plus the incoming uncommitted media changes. Nearest-integer
67% target: **314 → 210 inventory units** (**33.12% removed; 66.88% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 83 | 47 |
| Executed QML behavioral cases, including data rows | 216 | 148 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **314** | **210** |

This is the established mixed inventory, **not independent scenarios or a
coverage percentage**. The counter now recognizes line-wrapped daemon-contract
builders, previously undercounting five declarations as three; the same corrected
counter measures both snapshots. Other counting rules are unchanged.

**68 Qt behavioral cases were removed.** The 36-site JavaScript reduction mostly
consolidates repeated validation assertions and related output checks while
retaining their input cases; it is not 36 deleted behaviors. QML runner totals
**286 → 212** include **70 → 64** excluded lifecycle hooks. No tests were skipped
or renamed into undiscovered helpers. Three suites were deleted, and Lens loses
only the two corresponding explicit entrypoints.

Validation: 212 QML passes, all 16 behavioral JavaScript scripts, source-tree
relative imports, strict lint, runtime smoke, generated TypeScript verification,
TypeScript typechecking, eight Rust tests and both Python tests pass. All five
daemon contracts remain unchanged; the full sibling-aware Nix gate and contract
executables were **not rerun**.

Direct per-wrapper visual/size matrices, some happy-path restoration and consumer
wiring checks, exhaustive history schema variants, native slider End, RTL segment
navigation, outside-drop cancellation and standalone animation completion receive
less direct evidence. Essential behavior remains covered, but fewer tests do not
prove identical branch coverage. See the [review](../docs/reviews/test-pruning-2026-10-06.md)
for decisions, explicit gaps, per-suite counts and reproduction commands.
Evidence is in ignored `target/test-pruning-2026-10-06/`.

This checkpoint is not a permanent test-count cap. Add focused behavioral
regressions when a meaningful failure is found.

## Historical checkpoints

- [2026-10-05: 359 → 241](../docs/reviews/test-pruning-2026-10-05.md)
- [2026-10-04: 396 → 265](../docs/reviews/test-pruning-2026-10-04.md)
- [2026-09-27: 298 → 200](../docs/reviews/test-pruning-2026-09-27.md)
- [2026-09-26: 357 → 239](../docs/reviews/test-pruning-2026-09-26.md)

These describe earlier sources and validation, not the current suite. Always
count matching source snapshots and QML logs; the inventory script rejects
incomplete, failing, unexpectedly skipped or duplicate-case logs.
