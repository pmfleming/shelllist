# Lens cleanup checkpoint — 2026-10-02

## Scope and comparison

Baseline: Shelllist `528000e` **plus the pre-existing chooser-geometry worktree
patch**. That patch remains uncommitted and unchanged. Both sides were measured
with qmlqualitylens `e4fca82`; analyzer calibration is not an application gain.

Production excludes `tests/` and `dev/`, but retains generated sources. All-scope
figures also retain tests. Static comparisons disable native checks and imported
reports; independent native validation is recorded below. Clone limits are
200,000 keys, 1,000 windows/key and 10,000 groups on both sides, with zero omitted
windows/groups. No thresholds, suppressions or test expectations were weakened.

| Lens metric | Production before → after | All before → after |
| --- | ---: | ---: |
| Source LOC | 36,640 → 36,603 | 45,629 → 45,593 |
| Physical LOC | 41,041 → 41,000 | 50,363 → 50,323 |
| Components | 283 → 282 | 338 → 337 |
| Cyclomatic sum | 6,898 → 6,896 | 7,514 → 7,512 |
| Cognitive sum | 4,564 → 4,550 | 4,799 → 4,785 |
| Function effort sum | 35,039 → 35,018 | 41,174 → 41,154 |
| Component effort sum | 39,506 → 39,438 | 49,502 → 49,436 |
| Mean locality | 76.3781 → 76.3901 | 77.1095 → 77.1217 |
| Mean leverage | 36.8375 → 36.9149 | 32.4852 → 32.5371 |
| Clone groups | 127 → 125 | 172 → 170 |
| Clone-covered lines | 1,810 → 1,788 | 2,494 → 2,472 |
| `property var` | 424 → 422 | 455 → 453 |

Approximate function metrics and `ignoreUnknownSignals: true` remain zero;
existing lint disables remain 15. The aggregate heuristic score remains **83**.
Locality/leverage gains are small aggregate changes, partly from removing an
orphan component, not evidence of a broad architectural or runtime improvement.
Tracked regular `.qml/.js/.ts/.mjs/.py/.sh/.nix/.rs` files, including generated code
and tests, total 55,670 → 55,631 physical lines. Documentation is additional.

## Changes and review decisions

- Replaced clipboard action condition chains and tray dispatch with explicit
  switches. Media seek dispatch computes its offset once; capability, identity,
  active-surface and menu guards are retained. `perform` changes from cyclomatic
  19/cognitive 30/effort 107 to 18/23/98; `triggerAction` from 9/18/59 to 8/11/47.
  Normal multiline formatting is retained rather than compressing branches to
  manufacture LOC savings.
- Removed repeated card sizing and padding that exactly duplicated inherited
  defaults. The shared content-sized card contract remains authoritative; layout,
  narrow-window and battery tests still exercise the consumers.
- Typed the actual `KeyedListModel` references in `ResultStore` and
  `ProviderChooserController`; arrays, snapshots and protocol payloads remain
  appropriately dynamic. No generic `QtObject` cast or lint escape was added.
- Removed three unused IDs, the unused chooser-header `signalIcon` property and
  the uncustomized `headerIcon` pass-through. List-row signal rendering remains.
- Removed `RefreshTile.qml` and its qmldir entry after reference/entrypoint and
  consumer review found no use beyond its export. This application-owned module
  is not treated as an external compatibility SDK. The lens finding alone was
  **not** proof that an arbitrary exported library type can safely be deleted.
  Corrected-analyzer cleanup reviews decrease from four to zero; this is not a
  claim that all possible dead code has been proven absent.
- Added an unknown-action no-op assertion to the clipboard recovery regression.
  Kept `BluetoothListOptions`: inspection found a real adapter-page consumer.

## Validation and remaining limits

- Full sibling-aware gate passed:
  `python3 ../daemon-framework/tools/local-build.py check . --keep-going --print-build-logs`.
- 316 QML tests passed; strict qmllint and runtime smoke checks passed.
- Final native lens run: qmllint clean over 391 QML/JS inputs; both parser oracles
  passed 337 QML files; 316 executed tests, zero failures; runtime evidence passed.
- 4,352 frozen-input before/after dispatch comparisons passed, including inactive
  surfaces, missing/disabled actions, explicit player IDs, tray availability,
  image/link gates, backend false returns and prototype-like unknown actions.
  These are isolated mocked comparisons, not live desktop action tests.
- Overall native quality contract is still **incomplete**, with zero verified or
  semantic failures. Existing semantic abstentions and the existing qmlformat
  error in the SystemTrayItem test stub remain. Formatting drift stays at 83;
  default native clone coverage remains bounded. Do not call this a global green
  lens verdict or acceptance closure.

## Local evidence

Shelllist artifacts: `target/lens-campaign-20261002/` contains the baseline archive,
`pre-existing.patch`, native configurations/reports, full-gate log and
`differential.mjs`/`differential-final.log`. The frozen checkout initially omitted
that patch; applying it reproduced every pre-refactor aggregate exactly before
accepting the comparison. The live patch was byte-checked unchanged.

Lens artifacts: `../qmlqualitylens/target/shelllist-campaign-20261002/` contains
`snapshot.mjs`, `baseline-pinned{,-summary}.json` and
`checkpoint-1-final{,-summary}.json`. Final source hash:
`4900e08bc81e5bfb69ea2f87fd2a6f1249f87c476d9bbf1230df435ef57aca40`.
Artifacts are local/ignored; this review records the durable checkpoint summary.

Native measurement, from the Shelllist development environment:

```sh
nix develop --no-write-lock-file --command node ../qmlqualitylens/dist/bin/qmlqualitylens.js \
  measure all --config target/lens-campaign-20261002/checkpoint-1-native.config.json
```

Local commits only; no remote push or broader lens acceptance claim.
