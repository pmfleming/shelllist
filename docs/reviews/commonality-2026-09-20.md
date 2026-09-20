# Shared frontend quality review — 2026-09-20

Baseline: Shelllist `e33b0aaa1a5ed6b8a9e89271fcb5adbc9f6b6ffe`.
Tool: local `../qmlqualitylens`, revision `ac6a1f6b8fcef4d097512a81b937b6662e7a3d16`.
The same built Lens, source roots, thresholds and unsuppressed rules measured both snapshots.
This is a bounded refactoring pass, not a claim that all maintenance debt is gone.

## Findings and changes

1. **Model ownership was duplicated.** `ResultStore` managed reconciliation and
   chunked loading; the bar implemented another reconciler that reset delegates
   on membership changes. `Core.KeyedListModel` now owns both. Wi-Fi, Bluetooth,
   Clipboard and Applications consume it through `ResultStore`; the bar consumes
   it directly. Small changes preserve delegate identity, large replacements
   remain chunked, stale queued chunks are fenced, and bar equality checks still
   avoid unnecessary updates. Selection, search and domain state stay outside.
2. **Activation behavior had drifted.** `Ui.ActionControl` now centralizes guarded
   Enter/Return/Space activation, auto-repeat rejection, assistive press actions
   and busy-focus policy for buttons, tabs, toggles, action areas and bar actions.
   Checkboxes share assistive toggle handling. Bar actions retain distinct mouse
   buttons/wheel behavior and gain accessible names, focus indication and tooltips.
3. **Some indirection was unnecessary.** Replaced mutable `refreshHandler` and
   `pickHandler` callbacks with explicit typed method overrides, including the
   Time & Weather consumer. Typed the bar backend's controller and Bluetooth
   loader casts; removed the latter's `missing-property` suppression. Hotspot/VPN
   cancellation reuses the existing backend's validation and failure reporting.
4. **Tests were retaining obsolete implementations.** Removed the launcher's
   unused resource-detail table and its private formatters, legacy single-operation
   Bluetooth transitions, unused media/application/noise-control helpers, four
   unused IDs and an unused import. Tests now exercise live resource formatting,
   availability/provenance and the actual Bluetooth queue. No daemon fields or
   live resource charts were removed. Dynamic controller properties flagged by
   Lens were checked against callers, not deleted wholesale.
5. **Hotspots needed simpler control flow.** Flattened Bluetooth queue handling,
   separated clipboard edit-begin/edit-commit recovery, and isolated bar job
   formatting. Wi-Fi deltas use indexed lookups instead of repeated linear searches,
   preserving ordering, first-replacement precedence and keyless networks.
6. **The lint gate could falsely succeed.** Nix passed isolated directories to
   qmllint, breaking relative test imports, and accepted warnings. It now uses
   the complete source layout and `--max-warnings 0`, as do the development and
   Lens wrappers. Full native Lens lint caught residual migration references;
   they were fixed and regression-tested rather than suppressed.

## Like-for-like measurements

Production excludes `tests/`; generated JavaScript remains included. These are
Lens's analyzed QML/JavaScript/module sources, not documentation or a second count
of their TypeScript inputs. Effort is heuristic, not elapsed developer time.
Locality/leverage means are unweighted production-component scores; resolved test
consumers still contribute to Lens's reuse counts.

| Metric | Before | After |
| --- | ---: | ---: |
| Production source LOC | 30,292 | 29,977 |
| Production physical LOC | 33,172 | 32,847 |
| All analyzed source LOC, including QML tests | 35,143 | 35,005 |
| Production function cyclomatic sum | 6,530 | 6,447 |
| Production function cognitive sum | 5,163 | 5,073 |
| Production function effort sum | 30,656 | 30,140 |
| Production component effort sum | 40,540 | 40,402 |
| Mean component locality | 74.875 | 75.156 |
| Mean component leverage | 52.345 | 52.953 |
| Clone groups with ≥2 production occurrences | 159 | 158 |
| Production lines covered by clones, union | 2,270 | 2,254 |
| Unused ID candidates | 4 | 0 |
| Unused component cleanup candidates | 0 | 0 |
| Rounded overall score | 85 | 85 |

`ResultStore` locality/leverage improves **84/23 → 89/44**; the bar's improves
**20/11 → 24/15**. New `KeyedListModel` scores **100/75**, and `ActionControl`
**100/100**, with two and six production consumers respectively.

Selected function cognitive changes, **including extracted helpers**:

- Bar update presentation: **27 → 17**.
- Bluetooth pairing queue: **26 → 18**.
- Clipboard failure handling: **25 → 18**.
- Wi-Fi delta merging: **17 → 12**.

Tradeoffs remain visible: Wi-Fi merging's cyclomatic count rises **8 → 10** in
exchange for indexed lookup; clipboard's split handlers total **14 → 16**.
The overall production cyclomatic sum nevertheless falls. Complete normalized
clone groups **including tests** rise **202 → 204**; production duplication falls
slightly, not dramatically. Declarative data tables and generated protocol files
were not abstracted merely to manipulate clone scores.

## Validation and remaining work

- Complete current-worktree Nix flake check passed, including warning-fatal lint,
  packaging/imports, TypeScript generation, daemon contracts and policy tests.
- Native Lens qmllint: **347 files, zero errors/warnings/information diagnostics**.
- Real Qt suite: **247 passed, zero failures**, including hooks/data rows (231
  baseline). New tests cover delegate identity/reordering, unusual string keys,
  interrupted progressive loading, pointer/keyboard/assistive activation, busy
  controls, bar secondary actions, Wi-Fi delta precedence and Time & Weather loading.
- Offscreen Quickshell shared-UI smoke passed with no runtime-warning findings.
- Lens verdict remains **warn**, with zero verified failures. Remaining evidence:
  88 formatting-drift files, two oracle count disagreements in the existing
  `tst_search_action.qml`, one unresolved internal test type, partial profiler
  observations, and one noisy benchmark. These are not suppressed or called passes.
- Three exported UI components are outside current reachability; they were not
  assumed dead merely because this repository has no resolved consumers.
- Large battery/clipboard/Wi-Fi/Bluetooth controllers and popup/surface lifecycle
  ownership remain follow-up targets. Notifications still have a separate model
  adapter with different scalar-role constraints; it was not blindly folded in.

No live services were restarted, no wireless/display configuration was changed,
and no live-session latency/FPS improvement is claimed.

## Reproduction and evidence

Run `tests/check-sibling-boundary.sh` for the authoritative worktree gate. For
executed Lens evidence, from the Shelllist development environment:

```sh
tests/run-performance-benchmarks.sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
```

Executed reports are in ignored `target/qmlqualitylens/`. Comparison reports,
configs and the comparison/expanded-clone scripts are preserved locally in
`target/quality-review-2026-09-20/`. Static comparison configs copy the repository
configuration, set `project_root` explicitly, and use empty `tools`/`reports` to
avoid mixing execution evidence into structural measurements. Recreate the
baseline from the Git revision above; do not compare against older Lens reports.

Expanded clone analysis uses `analyzeClones(sources, config.thresholds.cloneWindow,
{keys: 200000, windows_per_key: 1000, groups: 10000})` on both snapshots: **zero
omitted windows/groups**. Default Lens clone output remains explicitly partial;
its capped 100-group result is not the exhaustive count used in this table.
