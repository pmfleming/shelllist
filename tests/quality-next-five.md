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
