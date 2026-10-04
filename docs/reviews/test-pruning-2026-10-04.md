# Test pruning — 2026-10-04

## Baseline and result

Baseline is HEAD `8331047331bcefc8b1eb4b0a6db9f300a1bec8ed` **plus the incoming
uncommitted interaction-maintenance changes**, not clean HEAD. The preceding
Lens maintenance review describes that incoming snapshot; its test totals are
historical after this pruning pass.

Using the unchanged `tests/count-test-inventory.py` convention:

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper source sites | 99 | 80 | 19 |
| Executed QML behavioral cases, including data rows | 286 | 174 | 112 |
| Rust tests | 4 | 4 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **396** | **265** | **131** |

`round(396 × 0.67) = 265`: **66.92% retained, 33.08% removed**. These mixed
inventory units are not independent scenarios, runtime assertion counts or a
coverage percentage. Calls inside JavaScript loops count once per recognized
source site. QML lifecycle hooks are excluded: runner totals are **374 → 244**,
including **88 → 70** hooks. Both runs have zero failures, skips or blacklisting.

No tests were renamed out of discovery, merged into larger tests to conceal
cases, or moved into uncounted helpers. Whole tests and redundant observations
were deleted; matrices retain representative rows. Single-row fixtures were
simplified without changing their behavioral count. Unused fixtures/imports
were removed. No production implementation was changed by this pass.

## Decisions and remaining owners

| Removed/reduced | Rationale and retained protection |
| --- | --- |
| Layout catalogues, repeated display/work-area widths, exact typography, tonal/hover/focus shape and spring/interpolation catalogues | Avoid prescribing a particular visual implementation. Keep native live/fractional expansion anchoring, negative-origin/reconnect work areas, keyboard overflow revelation, emergency bar access, native SVG decoding, foreground binding types and contrast across 150 seed/mode combinations. Shared control tests still exercise focus, masking, disabled/busy activation and immediate slider feedback. |
| Repeated chooser and consumer browse/edit journeys; old help/Activity shortcut-removal scenarios | Shared field and chooser suites own the mandatory paradigm. Keep actual Applications acknowledgement, modal containment, read-only/removed editors, query typing, and domain recovery rather than another copy of the same successful key sequence. |
| Binding/key and traversal availability cross-products | Keep save/discard binding checks for both string editors, slider Home-discard/End-save and live rollback. Both directional disable regressions remain; hidden-field rows also skip unavailable neighbours. Actual field removal remains tested in both directions. Unbound values, backend changes during editing, blur, no-op cancellation, switch arrival and pointer transactions remain. |
| Ordinary/recreated query, named-list-button, duplicate per-tab/per-consumer memory journeys and synthetic scroll-readiness internals | Keep value-free/clamped panel restoration, native selection across result switches, keyed viewports, real asynchronous editor recreation, newer-navigation cancellation, invocation closure fences, missing/disabled/password targets, per-result scroll/tab memory and immediate row toggles. Bluetooth retains refresh readiness, changed-adapter identity and sensitive closure; Applications retains menu closure and fresh authoritative history. |
| Action-row sizing/style matrices, default forwarding wrappers and another header reorder scenario | Keep pointer/keyboard/assistive activation via switch/workspace representatives; bar secondary routing; explicit/disabled/duplicate command keys; overflow selection/focus restoration; content-menu availability changes; and the recent close-time model-reordering regression. |
| Bluetooth radio/settings happy paths, Clipboard metadata/copy-route/warm-cache observations, display hierarchy/normalization, battery profile wrapper and some system-chooser presentation journeys | Prefer shared controls plus real domain failure boundaries. Retain pairing request identity and secret clearing, rename/adapter acknowledgement and failed drafts, audio apply-before-remember, scoped reset, clipboard leases/conflicts/retries/query fencing, annotation and revision-checked bulk deletion, display last-output/topology/preview/revert safety, battery protection and unknown outcomes, notification reply/DND recovery, Wi-Fi secret fencing/partial saves, and native tray-menu lifetime. |
| Chart pixel snapshots, helper-only work-area/segmented navigation/resource-summary projection and media-chip click catalogues | Keep chart inspection/Escape behavior, JS invalid/missing/zero/clock-reset/late-cache data checks, native segmented navigation/disabled/accessibility guards, resource unavailable-versus-zero contracts, explicit media targeting/capability guards and mode presentation checks. |
| Provider toggle/default/grouping observations, Bluetooth array-allocation identity, a display rectangle example and proposed translucent-shell contrast | Remove constructor mirroring and implementation/presentation assumptions. Keep provider duplicate-action/cross-provider rejection, real registry routing, pairing progress/visibility policy, unsafe-layout/finite-geometry validation, and opaque role/surface/focus contrast. |

### Deliberate gaps

This is a reduction in direct coverage, not a claim that every deleted assertion
has an equivalent replacement. In particular:

- Exact focus paint/hover/tooltip, spring reversal and no-motion endpoints,
  chart pixels, reference palette colors and seed-change reactivity are no longer
  separately certified. OSD dismissal/reopening and all brightness failure routes
  remain, but not the repeated per-value fill/thumb formula checks.
- Slider RTL/vertical pointer mapping, every wrapper and every width/scale are
  not individually tested. Native horizontal mapping and segmented RTL remain.
- Exact `Keys.forwardTo` array manipulation, modifier-hint timing, named list
  button restoration, synthetic pre-layout reveal state, and every combination
  of newly changed selection/context and queued restoration are not pinned.
- Direct media-chip child click routing, earbud artwork/percentage composition,
  some radio/profile/volume/copy-button callback wiring, warm clipboard cursor
  reuse, resource-summary projection and lazy-controller allocation details have
  less or no dedicated consumer coverage. Domain failure tests do not prove all
  of those presentation or wiring details.
- Activity's former surface composition/shortcut exclusions are no longer held
  as backward-compatibility requirements. Sensitive-input exclusion and current
  shared keyboard behavior remain covered.

Add a focused regression if a meaningful failure appears; this count is not a
permanent quota. Live compositor, hardware, IME, screen-reader and installed-build
acceptance remain separate from these offscreen tests.

## QML suite changes

Unlisted suites are unchanged in behavioral count.

| Suite | Before | After |
| --- | ---: | ---: |
| ActionControl | 5 | 3 |
| ActivityPlacement | 1 | 0 |
| BarOsdResponsiveness | 8 | 7 |
| BatteryHistory | 3 | 1 |
| BatterySuspend | 5 | 4 |
| BatteryTabs | 2 | 1 |
| BluetoothRecovery | 25 | 19 |
| ChartDrawing | 1 | 0 |
| ChooserGeometry | 14 | 5 |
| ChooserKeyboard | 14 | 7 |
| ChooserMemory | 31 | 15 |
| ClipboardRecovery | 15 | 12 |
| DetailLayout | 4 | 0 |
| Displays | 25 | 18 |
| DomainWorkflows | 7 | 3 |
| ExpressiveControls | 3 | 0 |
| FieldInteraction | 36 | 27 |
| FocusFeedback | 7 | 0 |
| MaterialBar | 5 | 3 |
| MaterialPalette | 2 | 1 |
| MediaChip | 3 | 0 |
| ProviderShortcuts | 3 | 2 |
| ResourceHistory (`tst_resource_palette.qml`) | 1 | 0 |
| SearchAction | 3 | 0 |
| SegmentedNavigation | 1 | 0 |
| SettingsControls | 7 | 3 |
| SurfaceActions | 7 | 2 |
| SurfaceRegistry | 3 | 1 |
| SystemChoosers | 9 | 6 |
| TimeWeatherSelection | 2 | 1 |
| WifiCasting | 4 | 3 |

## Validation and preservation

Passed:

- Native QML: **244 passes = 174 behavioral cases + 70 lifecycle hooks**.
- All **16 behavioral JavaScript scripts**, plus packaged-import checking.
- Strict native lint, runtime smoke and generated TypeScript checking.
- Both Python profiler tests and `git diff --check`.

Rust tests, daemon contracts and their declarations were not pruned. The full
sibling-aware Nix gate, Rust execution and daemon contract execution were **not
rerun** in this pass; historical Nix results are not current evidence.

The incoming `flake.nix` patch is byte-identical. All **2024 recorded production
file hashes**, incoming non-test tracked diffs, the untracked `ActionMenu.qml`
and the preceding maintenance review are preserved. The only Lens configuration
change removes the nine deleted test entrypoints; source roots, exclusions,
suppressions, tools and thresholds remain unchanged. Runner/discovery/counting
scripts are unchanged. No rebuild, restart, deployment or commit was performed.

## Reproduction and evidence

Ignored `target/test-pruning-20261004/` contains the incoming patch, separate
flake patch, baseline test/config archive, untracked-file copies, production
hashes, before/after QML logs and inventories, validation logs and preservation
checks. Reconstruct the baseline from these inputs, not clean HEAD alone.

```sh
tests/run-qml-tests.sh > target/test-pruning-20261004/after-qml.log
python3 tests/count-test-inventory.py \
  --qml-log target/test-pruning-20261004/after-qml.log
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
node tests/check-packaged-imports.js .
node tools/build-typescript.mjs --check
python3 -m unittest discover -s tests -p 'test_*.py'
git diff --check
```

Run each `tests/check-*.js` with its `flake.nix` arguments; the JavaScript log
records every command. Material contrast uses
`qml/Shelllist/Ui/MaterialColors.generated.js`. Baseline and final source counts
must be paired with their matching logs. No performance or complete Lens
certification is inferred from the smaller suite.
