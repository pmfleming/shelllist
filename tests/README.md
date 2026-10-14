# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables or freeze visual choices unnecessarily.

## Panel standardization acceptance

`docs/panel-ui-standardization.md` records current roles, the twelve-panel matrix,
exceptions and separate source/offscreen/live evidence. Those are historical
acceptance results, not a claim that every visual matrix remains automated.
Shared field/command tests retain interaction and native identity. Standalone
long-diagnostic geometry, `PanelRoles` and per-family/Weather geometry matrices
were removed across pruning passes. Historical manual all-panel captures record
fixed status bounds and representative real-consumer error transitions; those
presentation choices are not mandatory contributor requirements. See [current convergence evidence](../docs/shared-panel-ui-convergence.md);
pruning checkpoints below describe historical source snapshots, not this run.
The explicit manual capture fixtures cover panels, dense forms and display safety
states. Generate the local comparison gallery with `tests/build-panel-gallery.py`;
use `tests/review-panel-ui.py --base <ref>` as an advisory PR drift review, not a
blanket ban on numeric domain geometry. Neither freezes screenshots as goldens.

## Retained coverage

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG plugins, timezone data and the same
Fontconfig configuration as the application. Both QML runner scripts use the same
offscreen/software, UTC setup. Refresh an existing development shell after changing
`flake.nix`. Without Material Symbols, literal icon names can overflow adjacent
cards and produce misleading chart-pixel failures; the resource pixel test checks
that prerequisite rather than skipping or weakening its paint assertions.

- `tst_field_interaction.qml`: local drafts, binding survival, backend updates
  during editing, native arrows, forward/reverse Tab after availability changes
  and reverse Tab after removal, editable-only traversal, switch safety,
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
  workspace activation, monitor-local selection/reveal and unavailable versus
  zero battery readings. Exact chromatic/occupancy paint, whole-bar layout and
  positive battery-fill matrices are no longer automated here.
  `tst_media_chip.qml` samples narrow seek transport, circular artwork geometry,
  and keeps missing-player controls visible but disabled; system choosers exercise
  panel transport. Its RHI-only artwork pixel check remains an explicit existing
  skip under the software runner.
- Daemon/session and model suites retain protocol/generation boundaries,
  request churn, stable identities, queued-update cancellation and
  progressive/native list updates. Wi-Fi retains cancellation acknowledgement.
  Notifications retain atomic center refresh, obsolete-read rejection, queued
  revisions, timeline viewport restoration and reply ownership across reconnects.
- JavaScript retains unsafe-layout/numeric validation, unavailable versus measured
  zero, chart gaps, history/cursor failures, request identity, no-replay rules and
  battery safety. Material contrast covers 150 seed/mode combinations. Native
  QML checks actual field pixels and SVG decoding. Runtime smoke exercises native
  offscreen windows and chooser geometry; `tst_work_area.qml` covers authoritative
  geometry and failure recovery.

Expected negative-test application error logs are distinct from QML engine
warnings and remain allowed. Offscreen tests do not replace live compositor,
hardware, IME or screen-reader acceptance.

## Current pruning checkpoint — baseline `46407b7`

**618 → 414 inventory units: 204 removed (33.01%), 66.99% retained.**
The unchanged counter gives `round(618 × 0.67) = 414`. Actual reductions are
202 Qt cases/data rows and two hard-coded JavaScript schema-cardinality assertions;
no filtering, hidden tests, scenario packing or new skips. Production, fixtures,
runners and all five daemon contract checks are unchanged.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 68 | 66 |
| Qt behavioral cases/data rows, including existing skip | 535 | 333 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Total** | **618** | **414** |

Full Qt: **460 passes, zero failures, one existing renderer skip** (332 executed
behaviors + 128 excluded lifecycle hooks). Sixty-four suites remain. This mixed
inventory is not coverage; 414 is not a cap on future regression tests.
See [decisions, retained owners, validation and explicit gaps](test-pruning-current.md).
Strict lint, Python tests, runtime smoke and the full current-source
`local-build check shelllist --offline --keep-going` passed. The Nix Qt run
independently reports the same 460/0/1 result with regenerated producer fixtures.
Matching local evidence is in `target/test-pruning-46407b7/`.

## Historical ownership regressions

The [ownership refactor](../docs/ownership-refactor.md) adds 14 focused native
cases after pruning: notification completion fencing, chooser restoration
fallbacks/readiness, and clipboard captured-target/paste ownership. At that checkpoint,
the full Qt run had **606 passes, zero failures, one existing renderer skip** (482 executed
behaviors + 124 lifecycle hooks). Established inventory: **555**, including that
skip. Lint, all 17 JavaScript checks and runtime smoke pass at each refactor step.
The pruning figures below remain historical evidence, not a test-count cap.

## Previous pruning checkpoint — baseline c6451f8 + incoming work

**808 → 541 inventory units: 267 removed (33.04%), 66.96% retained.**
`round(808 × 0.67) = 541`, using the unchanged established inventory counter.
The baseline includes the preceding Lens refactor and all other incoming edits.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 57 | 57 |
| QML behavioral cases/data rows, including one existing skip | 736 | 469 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **808** | **541** |

All reductions are actual Qt cases/data rows across 23 files. Contract matrices
retain live request shapes and sample failures by state owner instead of crossing
every method with every error/reconnect condition. Compatibility-only routes,
repeated palette/layout/wording checks and duplicate per-surface input routes are
removed. Shared native editing, confirmation, ownership, stale replies, secret
handling, partial acknowledgement and no-replay tests remain. No production code,
runner, counter, build check, fixture or discovery change; no new skips.

Validation: **592 Qt passes, zero failures, one unchanged renderer skip**
(468 executed behaviors + 124 lifecycle hooks), strict lint, all 17 JavaScript
checks, two Python tests, four Rust search tests and native smoke pass. The four
portal-launcher Rust tests are blocked by an unchanged lockfile/dependency mismatch;
no lockfile was updated. Five daemon contracts and full Nix/hardware gates were
not rerun. The mixed inventory is not coverage, and retained shared tests do not
prove all removed endpoint/presentation permutations.

Historical decisions: `git show 46407b7:tests/test-pruning-current.md`.
Matching evidence is in `target/test-pruning-c6451f8/`. Earlier counts below are
historical; this target is not a cap on future regression tests.

## Previous pruning checkpoint — baseline aefcf52

Baseline includes the incoming uncommitted changes, not an older historical
checkpoint. **430 → 288 inventory units: 142 removed (33.02%), 66.98% retained.**
`round(430 × 0.67) = 288` under the unchanged established counter.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 76 | 57 |
| QML behavioral cases/data rows, including one existing skip | 339 | 216 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **430** | **288** |

The reductions are 123 actual Qt cases and 19 JavaScript assertion sites, mostly
repeated data rows, UI implementation/geometry checks, obsolete inline-tray tests
and transport scenarios duplicated by native Qt tests. No counter, discovery,
build-check or production changes; no new skips or hidden tests. Essential shared
editing, acknowledgement, destructive confirmation, stale ownership, secrets,
retry and no-replay workflows remain. The mixed inventory is not branch coverage.

Validation: **311 Qt passes, zero failures, one unchanged renderer skip**
(215 executed behaviors + 96 lifecycle hooks); all 16 behavioral JavaScript
scripts plus source-tree imports, eight Rust tests, two Python tests, QML lint
and native runtime smoke pass. The five retained daemon contract suites and full
Nix/hardware/RHI gates were not rerun.

Earlier decisions are retained in Git history. Matching baseline/final sources,
logs and inventories are in ignored `target/test-pruning-aefcf52/`. The older checkpoints below are historical, not
current coverage promises. This target is not a permanent cap on useful tests.

## Previous working-tree pruning checkpoint

Baseline included the incoming uncommitted changes at that earlier request.
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

The earlier decisions are retained in Git history. Matching historical baseline
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
prove identical branch coverage. The historical 2026-10-06 review is retired from the checkout; its decisions
and explicit coverage gaps are summarized above.
Evidence is in ignored `target/test-pruning-2026-10-06/`.

This checkpoint is not a permanent test-count cap. Add focused behavioral
regressions when a meaningful failure is found.

## Historical checkpoints

Retired review records (counts retained for history; files are no longer linked):

- 2026-10-05: 359 → 241
- 2026-10-04: 396 → 265
- 2026-09-27: 298 → 200
- 2026-09-26: 357 → 239

These describe earlier sources and validation, not the current suite. Always
count matching source snapshots and QML logs; the inventory script rejects
incomplete, failing, unexpectedly skipped or duplicate-case logs.
