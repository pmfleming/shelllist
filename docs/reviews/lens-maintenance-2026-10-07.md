# QML Quality Lens maintenance — 2026-10-07

## Scope and review

Baseline: working tree at `869a6167a4dcd7e245aeb088065413c1cdb4891b`, including
incoming `.gitignore`/`flake.nix` edits and staged proposal deletions, left untouched.
Local Lens: `../qmlqualitylens`, `6868f2f113ef14b53deae673baf0ac654d17e869`,
version 0.5.0; Node 24.16.0, Qt 6.11.1. Analyzer configuration, source roots,
suppressions and protocol generators were not changed.

Implemented findings:

- **Dead resource presentation:** Lens flagged `ApplicationResourceMetadata` and
  `ApplicationResourceBadge` as unreachable. Repository reference checks confirmed
  only their exports, mutual use and historical documentation remained. Removed
  both components/exports and five orphaned helpers (`metadataBadges`, its two
  builders, `integer`, `duration`). Edited the TypeScript source of truth and
  regenerated `ApplicationResources.js`. Current process-coverage warnings,
  attribution caveats, energy confidence and availability checks remain live.
- **Repeated reading wiring:** `ApplicationResourceCapacity` now consumes the
  existing snapshot descriptor once, rather than repeating identity, value,
  availability, accessibility and color bindings at three creation sites.
  Removed unused label/unavailability switches; presentational glyph/size overrides
  remain local. Descriptor replacement remains reactive, not a copied snapshot.
  The descriptor is an intentional JSON `var` boundary, not a claim of static
  payload typing; this adds one `var` while dead components remove four.
- **Duplicated tab geometry:** Wi-Fi now uses `TabbedDetailsStack`, joining its
  five other consumers. Clipping, footer sizing and spacing have one shared
  implementation. Wi-Fi still owns its asynchronous loading, slide transition,
  saved-profile guard, page selection and domain save/acknowledgement logic.

Not consolidated: normalized option tables, imports and generated protocol
strings do not necessarily represent shared behavior. No generic domain-action
router, panel-local key model or weakened guard was introduced.

## Measured results

Production excludes `tests/` and `dev/`; all-source figures include the new
native regression and extended resource assertions. Effort is Lens's weighted
function heuristic, **not developer hours or aggregate Halstead effort**.

| Metric | Production before → after | All sources before → after |
| --- | ---: | ---: |
| Source lines | 39,528 → 39,419 | 50,137 → 50,072 |
| Physical lines | 44,099 → 43,974 | 54,994 → 54,913 |
| Components | 307 → 305 | 366 → 364 |
| Function cyclomatic | 7,640 → 7,621 | 8,513 → 8,495 |
| Function cognitive | 5,173 → 5,159 | 5,552 → 5,538 |
| Function effort | 38,212 → 38,131 | 46,054 → 46,006 |
| Component effort | 43,929 → 43,832 | 56,032 → 55,973 |
| Mean leverage | 38.2248 → 38.4262 | 33.5109 → 33.6538 |
| Mean locality | 74.8795 → 74.8295 | 75.6967 → 75.6593 |
| Normalized clone groups | 117 → 118 | 162 → 163 |
| Clone-covered lines | 1,635 → 1,638 | 2,319 → 2,322 |
| `property var` occurrences | 458 → 455 | 501 → 498 |

Tracked code across QML/JS/TS/scripts/Nix/Rust falls **61,804 → 61,680 lines**,
including tests. Cleanup findings fall **3 → 1**; the retained finding is the
intentional SystemTray `Status` enum test stub. Unknown-signal suppressions remain
zero; lint-disable occurrences remain 15.

**Not every aggregate improves.** Deleting highly local dead components lowers
mean locality slightly. Changed consumers improve: ResourceHistory **47 → 53**,
ResourceOverview **56 → 67**, NetworkDetailsPane **49 → 51**. TabbedDetailsStack
leverage rises **75 → 90**. The new normalized clone is the ordinary shared-stack
configuration now present in Wi-Fi, Applications and Time & Weather. Actual
repeated geometry/data wiring was removed, but measured clone count did not fall.
The broad uncalibrated score moves **83 → 82**; this is not an across-the-board
quality-score win. Complexity reductions here come from removing dead functions,
not simplifying the largest surviving state machines.

## Validation and reproduction

Passed:

- Native Qt suite: baseline **447 passed, 0 failed, 1 skipped**; final **448 passed,
  0 failed, 1 skipped**. Existing RHI-only media clipping test remains skipped on
  the software renderer. New Wi-Fi coverage delivers Ctrl+Tab/Shift+Ctrl+Tab,
  Tab, native arrows and Escape through the real chooser: guarded tabs, result
  focus retention, asynchronous pages, draft discard and no profile writes.
  Resource arrival additionally checks live display/accessibility updates while
  its range editor retains an unsaved draft.
- Strict `tests/run-qmllint.sh` and Lens's native lint evidence.
- `tests/run-runtime-smoke.sh`: both real Quickshell fixtures load offscreen.
- Resource arithmetic/availability JavaScript checks, generated TypeScript check,
  `tsc --noEmit`, and `git diff --check`.

Evidence: ignored `target/lens-review-2026-10-07/`. `before/` and `after/` contain
stock `quality.qml`, `quality.locality_dynamic`, `quality.locality_leverage` and
`quality.cleanup` artifacts, invoked with the unchanged project config:

```sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure quality.qml \
  --config qmlqualitylens.config.json
```

The local `snapshot.mjs` uses the same Lens API/settings for both snapshots.
Default clone analysis is capped; the table instead uses complete inventories
with identical limits of 200,000 keys, 1,000 windows/key and 10,000 groups. Neither
snapshot omitted windows/groups. No formatter, full `measure all`/audit,
coverage/performance campaign, package build or daemon contract matrix was run.
Static rule coverage remains partial; runtime speedup and hardware/compositor,
IME or screen-reader acceptance are not claimed.

## Remaining priorities

Largest surviving production functions, shown as cyclomatic / cognitive / effort:

- `ChooserSession.apply`: **19 / 26 / 99**. Focus restoration spans asynchronous
  readiness, invocation ownership and user cancellation; preserve those fences.
- `ApplicationOperations.apply`: **23 / 24 / 109**. Admission, checked handoff,
  partial placement failure and close reconciliation need separate behavioral
  evidence before changing ownership/state transitions.
- `SystemChooserController.perform`: **18 / 23 / 100**. Any routing simplification
  must retain fresh capabilities, explicit media targets and unique tray identity.
- `WifiConnectionController.receiveStatus`: **20 / 20 / 93**. Malformed/late reads
  must not release mutation ownership or replay connection effects.

These are follow-up review targets, not proof of defects and not resolved by
this bounded maintenance pass. See the unchanged-behavior addendum in the
[interaction contract](../chooser-keyboard-workflow.md).
