# Evidence-aware QML maintenance follow-up

Analyzer: qmlqualitylens `b5ab651` (all three clean native profiles validated).
Inputs: frozen before/delivery worktrees, including all pre-existing changes.
The concurrent `1e31be1 → 497463f` commit changed documentation only; source
inventory differences are this refactor. No existing work was reset or folded
into this refactor's commit, including the pending Ui/qmldir removal.

## Changes and behavioral boundaries

- `Ui.PointerActionControl` owns ordinary pointer activation and typed hover/press
  state for seven production controls. `ActionControl` remains the keyboard/accessibility
  base; multi-button/wheel surfaces keep their specialized adapter. Busy-focus
  behavior is retained through `pointerEnabled` where it previously differed.
- Media transport uses a direction index instead of repeated nested forward/backward
  ternaries. Display edge selection uses explicit edge distances, preserving order,
  inside-tile priority, thresholds and hysteresis.
- Bar pointer/wheel routing calls its known signals directly, removing two indirect
  dispatch patterns. This trades a little local branching for explicit behavior.
- Removed the uncalled legacy backend reply RPC and descriptor (replies are owned
  by NotificationState), unused ActivityApi subscription list/toggle descriptor,
  and the unreferenced `securityControls` id. Compatibility fallbacks that still
  have callers and the uncertain exported Status enum were retained.

No rules, thresholds, source roots, suppressions, execution permissions or formatter
workarounds changed. No generated code was omitted from analysis. The formatter's
valid `property string id` failure was not hidden by renaming the mock API.

## Fixed-input measurements

The complete structured comparison is in the sibling analyzer repository at
`acceptance/evidence-next-results/shelllist-refactor-comparison.json`; provenance,
full inventories and native summaries are beside it. Both function measurements
have complete syntax evidence and zero parser diagnostics.

| Analyzed scope, including tests/generated code | Before | Delivery |
| --- | ---: | ---: |
| Source LOC | 45,095 | 45,090 |
| Function cyclomatic sum | 7,887 | 7,875 |
| Function cognitive sum | 5,172 | 5,157 |
| Function effort sum | 41,965 | 41,926 |
| Component effort sum | 50,047 | 50,051 |
| Structural clone groups | 27 | 26 |
| Unused-id findings | 1 | 0 |

Production component effort falls **42,122 → 42,080**; added regression coverage
accounts for the aggregate increase. Production QML/JS physical LOC falls by **38**;
including QML/JS regressions it falls by **2**. These are small, bounded improvements,
not a whole-application simplification claim. The advisory score remains **83**.

Media transport cyclomatic/cognitive complexity falls **14/19 → 7/6**; display
edge selection falls **18/32 → 12/14**. Shared pointer behavior has seven production
consumers and observed leverage 100. All migrated controls improve locality:
ActionButton 56→66, ToggleRow 53→61, ToggleSwitch 91→96, DetailsTab 86→92,
ActionArea 96→100, DisplaySettingsLink 79→87, WeatherLocationCard 59→62.
An added button test is not counted as additional production reuse.

Normalized clone detection remains capped/partial. Its reported count of 100 is
not an exhaustive total; the eliminated repeated pointer wiring and structural
27→26 change are the supported claims. Metrics are uncalibrated maintenance
proxies, not runtime latency or proof of behavior preservation.

## Validation and remaining failures

- Native Qt 6.11.1 / Node 24.16.0 configured audit: **237 passing executions before,
  239 after**, zero failures. Focused activation/media cases pass; Node display
  checks now cover directional edges, shared edges and hysteresis.
- Frozen-before/delivery JS differential controls: **1,924 media + 7,140 display
  cases passed** (`/tmp/qml-next-consumer-differential.cjs`).
- Lint and runtime smoke pass; final JSON and SARIF decisions agree exactly.
- Both strict audits still **fail with exit 1**: 200 required semantic abstentions,
  one formatter execution failure and partial coverage. Formatting drift remains
  101; this refactor adds no drift files. Coverage maps 282/339 before and 280/340
  after; these are new observations, not exhaustive coverage or a determinism test.
- The Status enum mock retains two parser-oracle count disagreements. Do not treat
  those observations as corroborated or remove the export from an advisory unused
  report alone.

Earlier overloaded attempts retained test failures/timeouts; a standalone host Qt
run also lacked SVG plugins. Final native results use the declared consumer shell,
not those failed attempts or a weakened test expectation. Every source inventory
entry was rechecked after execution. The imported qmlbench input was copied, not
freshly benchmarked. Human intent review and the analyzer's broader calibration,
performance and operational acceptance obligations remain separate.

Raw final captures:
`/tmp/qml-next-final-before-native/`, `/tmp/qml-next-delivery-native/`,
`/tmp/qml-next-shelllist-before/`, `/tmp/qml-next-shelllist-delivery/`.
