# Architecture closure evidence

## Step 1 — current product integration

`local-build check shelllist --offline --keep-going` passed on x86_64-linux.
This captures current sibling sources, not deployed binaries. All five daemon
package/contract checks, framework checks, generated fixtures/bindings, QML lint,
TypeScript freshness and native QML passed. Nix reused matching successful
check outputs where available. Native QML: **651 passed, 0 failed, 1 existing
software-renderer skip**. Logs: `/tmp/shelllist-closure/step1{,-qml}.log`.

Sources at capture:

| Repository | Commit |
| --- | --- |
| daemon-framework | 1e023d12ed8facc30259a0ad5609e418b1a55d9a |
| app-daemon | 7afc66ab7e4406a57ac820f21aa8e5a75095db19 |
| bar-daemon | 4dfb44d5dc7693a0de0bb5c2adc0f597107385c0 |
| bt-daemon | 994fc5e48fd2bf9393d239136debefd3bafef92c |
| clip-daemon | ba2163baf539df2f789c3976479a61a013a1d553 |
| nm-daemon | c9f37c1c7cff5a5db8eaa88f6424ae843678590d |
| update-daemon | 3f05cf1bccdb280685e4a500b0b901fa055ef237 |
| shelllist | d13234e15153976f21cdcb1b1d29362010fe5d44 |

The older HTML ledger predates the coordinated v2 cutover. Current code already
uses v2 envelopes in all five daemons and a shared direct-bus boundary. Complete
typed method coverage and metadata-driven service policy remain separate gaps.
This gate proves packaged/isolated integration, not live hardware, compositor or
privileged update deployment. No live service was restarted.

## Step 2 — additional typed control coverage (partial)

Brightness and power-profile requests/results now derive schemas from the live
Rust DTOs. Bar has nine typed method contracts instead of three, plus typed
subscribed/changed/gap payloads for audio, brightness and power-profile streams.
The bar consumer uses the generated event validator. Production fixtures have
Node and native-QML schema gates; removing a required result/event field is
rejected. The Node gate passed; the captured native-QML product gate was still
running at this incremental commit. The intentionally ignored resume-automatic parameters remain accepted.
Native bar tests: 208 passed, one existing ignored test. Full captured product
validation: `/tmp/shelllist-closure/step2-nix.log`.

**Not complete:** other bar domains, BT, clipboard and NM still need complete
Rust-derived method/event declarations and generated types. Their current
name/fixture checks do not establish typed payload coverage. This incremental
commit does not claim the requested all-method closure.

The first full step-2 Nix run exposed eight old QML scenarios supplying partial
hand-built positive events. Recovery/OSD tests now start from the production
read fixture; validators were not weakened. Native rerun evidence is recorded
in `/tmp/shelllist-closure/step2-fixed-qml.log` (with file-XHR explicitly enabled).

## Step 3 — declared policy enforcement (partial rollout)

Shared service admission now applies declared request/result byte limits,
per-method and per-owner concurrent-handler limits, and acknowledgement budgets.
Reads abort their local future when their wait expires/disappears. Effects and
operation acknowledgements continue with capacity retained until the handler
finishes; expiry reports outcome-unknown, never safe-to-retry or rolled-back.
Domain cancellation retains its existing owner checks and intent semantics.
Cleanup uses the separate control lane. Quota entries are removed on completion,
read cancellation and panic; timed-out effects cannot silently free admission.

Connected: all eight app methods and nine typed bar controls. Other daemon
methods still use their existing shared aggregate boundary: **step 3 is not
fully rolled out**. Hung effects deliberately retain bounded capacity; no generic
middleware can safely undo them or claim cleanup of an external effect.

Validation: framework 37 tests and all-target Clippy passed; app 46 unit tests,
16 private-bus session tests passed (existing ignored tests retained); bar 208
unit tests passed, one existing ignored. Dedicated tests exercise two owners,
request/result bounds, acknowledgement expiry, abandoned waiters, retained effect
capacity, panic/read cleanup and the reserved cleanup lane. Existing private-bus
ownership tests remain green. Logs: `/tmp/shelllist-closure/step3-*.log`.

## Step 4 — actual update publisher/reader boundary

The serde-only contract crate now owns job status, job state and phase DTOs and
bounded versioned decoding/encoding. Worker publication and bar reading use the
same DTO; boot ID/PID/start-time and zombie checks remain in the reader. Worker
writes retain atomic replacement and durability. Display state does not authorize
privileged apply.

Bar tests depend on the worker **only as a dev dependency**. They call the actual
`readiness::publish`/`job::Status` and actual `read_state`/job reader, not a copied
writer. Tests cover two lock-serialized concurrent readiness publishers with
concurrent readers, concurrent job-status replacement, invalidation before artifact
retirement, ignored stale legacy readiness, unsupported/malformed/oversized job
records, and subprocess exit before publication, after running-status publication,
and after invalidation. Exiting without terminal publication is read as interrupted.
These are process-crash tests, not simulated filesystem power loss.

Validation: all 12 bar update-boundary tests passed; worker workspace passed
82 worker tests plus two contract tests (one existing ignored worker test).
Build-input alignment passed. Full source-captured Nix gate is recorded in
`/tmp/shelllist-closure/step4-nix.log`. Strict all-target bar Clippy exposed existing
`redundant_closure` in `api/audio.rs` and `items_after_test_module` in `timezone.rs`;
that Clippy run is not claimed as passing.

## Step 5 — send-time Wi-Fi classification and reliability baseline

Wi-Fi records the actual method, response handler, conflict domain, concurrency,
sensitivity and execution class at send time, without retaining request parameters.
Profile details/share/reveal are reads; update/forget/unknown variants are exclusive
effects. Cache-refresh reads can schedule radio scans and are classified as
operations, not reads. Scans/connects retain their own concurrency rules. Portal transactions
are effects in a separate conflict domain, not reads. Unknown methods fail closed
for link exclusion. Response/error routing no longer examines ID prefixes.

Shared backend metadata is recorded before dispatch and cleared on reply,
rejection/send failure and generation loss. Duplicate pending IDs cannot replace
classification. Call IDs resembling subscription/control IDs remain calls.
Metadata cleanup cannot delete a new request started by a completion callback.
Native tests cover misleading IDs, method variants, parameter mutation, duplicate
IDs, no secret retention, transport loss, local rejection and control-looking IDs.

Validation: final source-captured native QML **666 passed, 0 failed, one existing
renderer skip**; strict QML lint passed. Scoped production-gap recovery: nine
passes. App and update-worker all-target Clippy passed. Logs: `/tmp/shelllist-closure/step5-{qml,lint,recovery,app-clippy}.log`.
Full source-captured product gate: `/tmp/shelllist-closure/final-nix.log` (exit 0).
The intermediate step-4 and step-5 captures also passed. Final bar Nix tests:
214 unit tests plus both integrations passed, including the private native-idle
fixture. Final QML log: `/tmp/shelllist-closure/final-qml.log`. The initial
step-2 fixture failures are superseded by this passing gate. All five daemon
packages/contracts, framework, worker, bindings/fixtures, build-input alignment,
TypeScript freshness, QML lint and packaged UI checks passed together.

Reproduce the isolated measurements in the product dev shell:

```sh
QML_XHR_ALLOW_FILE_READ=1 tests/run-qmlquality-tests.sh \
  -input tests/qml/tst_bar_recovery.qml -o /tmp/shelllist-recovery.log,txt
QML_LOG=/tmp/shelllist-recovery.log tests/benchmark-architecture.sh
shelllist-perf resident --pid "$PID" --duration 5s
```

Committed sample: [architecture-reliability.sample.json](architecture-reliability.sample.json).
The second debug sample measured app round-trip p50/p95/p99 **3.35/5.91/8.25 ms**
over 200 requests through the actual JSONL bridge and private-bus daemon. Ten fake
launcher operations produced 31 events / 15,297 JSON bytes; zero transport
recoveries, zero idle events and zero bridge CPU ticks over two seconds. Bar's
source-local p50/p95/p99 was **10.72/17.14/22.63 µs**; 3,024 publications accounted
for 568,331 payload bytes. The paused 1,024-event burst coalesced 1,023 states,
caused no domain lag and no unrelated-domain traffic; the old capacity-128 ring
lost 896 transitions. The real QML policy reduced 100 producer-backed gaps to
two recovery reads (one flight plus bounded follow-up), with no pending work left.

A separate passive observation of the **already deployed** hidden shell measured
1.60% of one CPU core and 274.53 MiB PSS over five seconds; three bridges were
active. It is not a measurement of these modified sources. Compilation was active
during sampling. These short/debug samples are not release budgets, a comparison
against an equivalent deployed baseline, or a long-duration reliability study.
**No process split is proposed or implemented.** Repeat under controlled idle/load
and deployed failure scenarios before making that decision.

## Remaining closure gates

Steps 2 and 3 remain partial: complete Rust-derived method/event/type coverage
and per-method policy adoption outside app and the covered bar controls. Current
generated coverage is app 8/8 methods (11 event shapes), bar 9/58 (9 event shapes),
BT 0/17, clipboard 0/21 and NM 0/38 complete request/result schema pairs. BT's
existing parameter-only schemas are not counted as complete contracts. Step 5
has an initial measured baseline, not comprehensive five-daemon deployed latency
and recovery statistics. Live hardware, privileged deployment and power-loss
filesystem testing were not performed. The earlier ledger's completion claims
must not be expanded to cover these outstanding gates.

## Commit anchors

- Step 1: Shelllist `bed65ee`.
- Step 2 partial: bar `478f367`; Shelllist `455f6aa`, `be246d4` (later gap-fixture correction in the step-5 consumer commit).
- Step 3 partial: framework `06e8d72`; app `1b6cfc3`; bar `ab6d013`; Shelllist `dd93525`.
- Step 4: worker `9aa3f13`; bar `3a2a888`; Shelllist `4f20e02`.
- Step 5 measurements: app `d0d4b1e`; bar `5f779b2`; the paired Shelllist commit contains classification, native tests, benchmark runner and this record.
