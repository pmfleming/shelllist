# Next five Lens-guided improvements

Baseline: `2816e75`, including the five incoming Bluetooth/contract/keyboard-doc
edits, preserved outside these commits. Analyzer: local `../qmlqualitylens`
`6868f2f`, version 0.5.0; Node 24.16, Qt 6.11.1. Evidence and reproducible snapshot
script: ignored `target/lens-refactor-next/`. Same source scope and normalized
clone limits as the preceding review: 200000 keys, 1000 windows/key, 10000 groups;
no omitted windows/groups. Production excludes tests/dev only. Weighted effort is
a structural heuristic, not hours. No suppression, threshold or test discovery change.

## 1. Typed selection contract and provider-owned append

Add `Core.SelectionModel` for index/query/count and bounded movement. ResultStore,
Time/Weather and Notifications now implement the same typed chooser boundary;
test doubles use it too. Catalog reconciliation remains domain-owned: the shared
model intentionally does not clamp when count changes. Notifications keeps its
key-derived index and overrides movement through its existing guarded selection.

Clipboard no longer reaches through the generic selection object to invoke
`ResultStore.applyNormalizedBatch`. Its history append uses the provider controller's
existing query API with an append flag, preserving provider/query checks and keyed
selection. This removes a dynamic interface and duplicate movement implementations,
not domain data validation or the JSON payload boundary.

Production: source lines **43552 → 43544**, physical **48411 → 48404**, cyclomatic
**9249 → 9246**, cognitive **6591 → 6590**, weighted function effort **45082 →
45065**. Mean locality **74.1777 → 74.2613**, leverage **36.2801 → 36.3964**;
`property var` **523 → 522**. Clone counts are unchanged. SelectionModel leverage
is 75; ResultStore locality improves 89 → 90 and TimeWeatherController 77 → 78.

Validation: strict lint and full native Qt suite **205 passed, 0 failed, 1 existing
renderer skip**. Native chooser keys additionally check last-result clamping; a
Clipboard transport-boundary test checks append, stable selection and stale reads.
No interaction change: Up/Down browse results, search entry and field transactions
retain the chooser keyboard contract. Notification selection side effects and
Time/Weather's native identity restoration remain owned by those controllers.
