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
