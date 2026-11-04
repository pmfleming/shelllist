# Five ranked quality improvements — 2026-11-04

Baseline: `b0d9ddd`, the requested commit of all incoming work. The existing
configuration and local QMLQualityLens 0.5.0 evaluator are unchanged. Full static
reports and per-step native logs are under ignored `target/quality-next-five/`.

Ranking weighs measured complexity, consumer reach, duplicated policy, ownership
risks and available native regressions, rather than complexity alone:

1. Share bridge/socket response validation and close the bridge's malformed-reply
   acceptance path. Socket receive is the leading handwritten cognitive hotspot.
2. Flatten shared event routing while retaining subscription and generation fences.
3. Flatten clipboard receipt dispatch without weakening uncertain-operation handling.
4. Store unpublished notification app rows and their cursor as one staging value.
5. Reduce duplicate update-history capture policy in the existing window owner.

## 1. Shared transport response validation

`JsonlRouting.responsePayloadValid` now owns the payload contract used by both
the socket and bridge. The bridge rejects malformed correlation/payloads before
reply delivery or health reset, using its existing configurable protocol-error
recovery. Socket wire-ID admission, route checks, retained uncertain credit and
one late resource acknowledgement retain their owners and ordering. A late
resource is classified once rather than through duplicated uncertainty checks.

The real Qt bridge suite now rejects seven malformed shapes and checks that
none acknowledges work or resets retry health. Removed its one-row startup data
provider and the permanently false branch it left behind; the same drain/reopen
journey remains. Bridge: **11 passes**; socket: **24 passes**; zero failures/skips.
Changed-file strict QML lint and `git diff --check` pass. These are deterministic
transport fixtures, not native socket/hardware or rollout evidence.

## 2. Shared event routing

Flattened `DaemonSessions.routeEvent` into explicit unrouted and routed paths.
Generation, attached consumer, active subscription and native-ID checks remain
before delivery. The existing captured-receipt journey now rejects unrouted
native traffic, retired generations, absent consumers and foreign native IDs,
then demonstrates delivery through the owned route. No new test case or helper.
Qt cleanup: **32 passes**; request metadata: **7 passes**; zero failures/skips.
Strict changed-file lint passes. Route-event cognitive complexity **25 → 18**,
cyclomatic **17 → 17**, weighted effort **97 → 83**. This simplifies nesting;
it deliberately retains the number of ownership decisions.

## 3. Clipboard receipt dispatch

Flattened `ClipboardStateRecovery.received` after the shared history/detail fences.
Missing status payload, wrong action/ID, rejected operation metadata and normal
success each have one explicit return path. Mutation replies still reject invalid
metadata; status reads still retire uncertain owned work without effect replay.
The existing malformed-paste journey additionally verifies no effect is retried
when polling follows rejection. No new public API, state or test case.
Qt stream recovery: **14 passes**; controller recovery: **13 passes**; zero
failures/skips. Strict changed-file lint passes. Native backend receipts, retained
drafts, reentrant IDs, malformed operations and read-only reconciliation remain
covered by those existing suites.

## 4. Atomic notification staging

`NotificationCatalog` now holds unpublished rows/epoch/revision in one value,
consumed before validation and reinstalled only for an accepted continuation.
Removed two separately maintained properties and their repeated reset logic.
Request construction selects its cursor owner once; continuation capacity is
computed once. Exact-app scans retain the accepted cursor while dropping bounded
prefix rows, and the published window stays unchanged throughout staging.
The existing cache journey now checks published-array identity and full staging
release after failure. Fixture setup no longer writes three independent internals.
Qt cache: **10 passes**; notifications: **4 passes**; zero failures/skips. Strict
changed-file lint passes. Both app and timeline paths retain bounded browsing,
atomic refresh, short/malformed pages, stale retries, exact routes and native
commands through the existing tests.

## 5. History-window capture locality

`UpdateHistoryWindow.begin` now owns pure construction alongside its existing
continuation transitions and cache bound. It selects a retained/new/advancing
position once and shares that decision across cursor and offset fields. The
controller captures accepted state once and retains all dispatch/deadline,
translation, retry and publication ownership. `anchorIds` is reused for initial
capture and stale-cursor restart, removing their duplicate anchor policy.
The existing Qt refresh journey additionally checks that pending append retains
the exact immutable published prefix. No new test case or independent model suite.
Updates: **48 passes**, zero failures/skips; changed-file strict QML lint passes.

## Paired measurements and limits

Same evaluator/configuration, baseline `b0d9ddd` versus the five-change working
tree. Entries below are cognitive / cyclomatic / weighted function effort.

| Owner | Before | After |
| --- | ---: | ---: |
| Socket receive | 32 / 31 / 147 | 26 / 26 / 126 |
| Shared event routing | 25 / 17 / 97 | 18 / 17 / 83 |
| Clipboard receipt dispatch | 26 / 17 / 106 | 19 / 18 / 92 |
| Notification app acceptance | 24 / 23 / 106 | 26 / 24 / 113 |
| Updates request capture | 29 / 23 / 107 | 3 / 4 / 20 |
| Pure history begin (new) | — | 17 / 17 / 70 |

History capture also adds a small reused anchor helper, so the controller's
reduction must not be treated as the removal of all those decisions. Construction
now lives with the actual continuation model; dispatch stays in the controller.
Notification acceptance trades a small complexity increase for one atomic staged
value and removes two independent cursor properties. Clipboard's extra guard
return raises cyclomatic complexity by one while reducing nesting and effort.

Project function totals: cognitive **8,505 → 8,481**, cyclomatic
**12,348 → 12,351**, weighted effort **59,443 → 59,424**. Rounded project scores
remain unchanged (overall 82, locality 76, leverage 31, duplication 96). These are
advisory syntax metrics, not calibrated productivity or correctness measurements.
The revised source retains 537 discovered files with zero parser diagnostics.
Clone evidence remains partial at the existing 100-group reporting limit.

This pass does **not** achieve every original metric goal: Lens source lines grow
**58,564 → 58,598**. Physical code grows **22 production + 19 test = 41 lines**
across changed QML/JS files. Extra shared validation and negative-path assertions
are retained for behavior, rather than claiming a code/test-volume reduction.
No scope, thresholds or exclusions are changed to improve these results.
Numeric statement/branch coverage remains unavailable; the new negative native
journeys are behavioral evidence, not a percentage gain. No live daemon,
hardware, deployment, sibling package or release-performance acceptance is implied.

## Final verification

- Full Qt: **711 passed, 0 failed, 1 existing RHI-dependent artwork skip**,
  including lifecycle hooks. No new exclusions, skips or blacklisted cases.
- Strict full QML lint, generated-contract negatives, source-tree relative
  imports and `git diff --check`: pass.
- Panel UI review against `b0d9ddd`: zero changed-line or new-wrapper prompts.
  Shared keyboard transactions and visual roles are unchanged.
- Native offscreen Quickshell UI smoke: pass. It used the normal bar theme
  client; this is not isolated producer/socket qualification or rollout evidence.
- Every implementation was checked before its own commit. The full suite ran
  after all five code changes and before the fifth commit.

Reproduce with the existing development environment:

```sh
source .direnv/flake-profile-*.rc
tests/run-qml-tests.sh
tests/run-qmllint.sh
node tests/check-generated-contracts.js
node tests/check-packaged-imports.js .
python3 tests/review-panel-ui.py --base b0d9ddd
node ../qmlqualitylens/dist/bin/qmlqualitylens.js analyze --config qmlqualitylens.config.json --format summary
```

Machine-readable paired metrics: `target/quality-next-five/comparison.json`.
Per-step reports use the same evaluator fingerprint
`ecbe448644080d95c83fc67b09fdf409d983163a2b5166d7b7eeb2585c605655`.
