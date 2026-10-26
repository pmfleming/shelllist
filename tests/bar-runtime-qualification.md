# Bar private runtime qualification

**Status:** private debug/runtime checkpoint passed; coordinator review required.
Not sustained-load, release-performance, packaged startup or rollout acceptance.

## Scope and safety

The retained bridge is still the default. This checkpoint does not activate,
restart or install any service and does not exercise a live desktop.

Producer tests live in
`bar-daemon/src/daemon/battery_operations/socket_tests/process.rs` and its
`process/payload.rs` module. They spawn the **matching lib-test executable as a
separate OS process**, hosting the real `JsonlListener`, `BarDaemon` cached-read
and subscription coordinators, and battery `Operations` admission/cancellation/
retention. This is a private runtime-component process, not the production
`bar-daemon` monitoring entrypoint or an installed-session startup test.

The child has private HOME/config/data/cache/state/runtime/backlight/TMPDIR,
cleared environment and nonexistent bus/compositor endpoints. No private bus is
needed. Constructors do not start monitors; notification state is in-memory.
A fixture allowlist rejects other methods before dispatch. The battery future is
fake authorization/effect work, not a helper or hardware operation. Fixture state
and audit files contain synthetic labels only. No display, notification,
clipboard or application effects are allowed.

The fake battery entrypoint replaces only the work future passed to the real
coordinator; it is not a second implementation of battery policy or an assertion
that real durable battery/hardware recovery is covered. Cached reads and
subscriptions enter the existing `BarDaemon` methods directly, as the production
socket adapter does. Existing D-Bus/legacy compatibility remains supported and
unchanged.

## Acceptance cases

### Real process death

`process_crash_loses_private_outcomes_without_replay_or_peer_authority` kills
and reaps the private child with SIGKILL, verifies signal 9 and transport loss on
both old connections, and starts a new child against the stale private socket.
This is **not listener recreation inside a surviving process**.

The four kill points are:

- fake work started, acceptance receipt withheld (no operation ID received);
- acceptance receipt received, work still pending;
- cancellation acknowledged, reconciliation still pending;
- successful fake terminal outcome retained, initiating owner has not read it.

Before the crash, dropping one owner requests cancellation but does not free
battery admission until fake reconciliation completes. A healthy peer retains
its subscription/read access, cannot query/cancel foreign work or subscriptions,
and cannot start conflicting work during reconciliation.

After the crash, both connections are gone; there is no claim that an accepted
connection survives process death. New peers receive `subscribed` baselines and
new publication epochs. Old private operation status/cancel returns
`operation-not-found`: missing non-durable outcomes are **unknown**, not success
or permission to retry. Persistent synthetic work-audit labels remain unchanged
through recovery reads/status/subscriptions. New explicit work receives a fresh
owner-scoped ID and retains cancellation/admission guards.

The sleep-state case verifies that new subscriptions are baselines, not replayed
historical edges. It does not recover missed sleep/notification/OSD history.
The pre-receipt case intentionally has no ID to recover; it checks that reconnect
reads do not replay it, not that missing acceptance can be reconstructed.

### Production-default framing and writer failure

`default_request_ceiling_rejects_fake_effect_before_dispatch_and_resynchronizes`:

- accepts exactly **1 MiB excluding LF** (bar's default, not the framework's
  configurable 128 MiB maximum);
- rejects one byte over before fake effect dispatch;
- checks no work entered the coordinator and both the resynchronized sender and
  another peer can still read.

Two explicitly ignored heavy tests distinguish the API and wire boundaries.
`maximum_service_result_and_unknown_overflow_keep_owner_and_admission` uses a
synthetic typed battery error string and actual cached-read dispatch:

- exactly **16 MiB of API-result JSON** is accepted, excluding the outer socket
  record and LF (the existing `ServiceBoundary::new` limit);
- one byte over returns a bounded `outcome-unknown` API error, not truncated
  state, and leaves that owner and its accepted battery work alive.

`maximum_event_and_failed_writer_hold_battery_admission_until_reconciled` uses
actual `BarDaemon` battery subscriptions, typed publications and the socket writer:

- exactly **32 MiB including LF** is delivered as one complete JSONL event;
- one byte over produces no partial/successful frame and closes that owner;
- a non-reading peer triggers real kernel backpressure. Only this case shortens
  the fixture write timeout to **100 ms**; this is not production timing evidence.

The service's 16 MiB RPC-result boundary is not bypassed or raised to reach the
32 MiB writer ceiling. Events enter through their real subscription path.
Writer loss/caller release requests battery cancellation but holds its admission
until fake reconciliation; a separate healthy owner can still read another domain
and cannot acquire foreign authority. Rejected work does not run or replay.
These are synthetic framing ceilings, not maximum real battery/display content
or publication effects, and not a native Quickshell large-record experiment.

## Reproduction

Run only in an isolated sibling family. Stage new inputs with `git add -N` first.
All heavy commands must use the orchestration lock/private-environment helper:

```sh
cd bar-daemon
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/check.sh
# The outer shell supplies the pinned Cargo used to bootstrap sibling tooling.
"$CHECK" timeout 1500 nix develop ../daemon-framework --no-write-lock-file \
  -c ../daemon-framework/tools/local-build develop . --command bash -c '
    set -euo pipefail
    cargo test --locked --lib process_crash_loses_private_outcomes -- --nocapture
    cargo test --locked --lib default_request_ceiling -- --nocapture
    cargo test --locked --lib maximum_service_result -- --ignored --nocapture
    cargo test --locked --lib maximum_event_and_failed_writer -- --ignored --nocapture
    cargo test --locked --all-targets -- --test-threads=2
    cargo clippy --locked --all-targets --all-features -- -D warnings
    cargo fmt --all -- --check
  '
cd ../shelllist
"$CHECK" timeout 900 nix develop ../daemon-framework --no-write-lock-file \
  -c ../daemon-framework/tools/local-build develop . --command \
  env QT_QPA_PLATFORMTHEME=generic QT_STYLE_OVERRIDE=Fusion tests/run-qml-tests.sh
```

The child-only ignored test is an internal helper, not independent acceptance.
It returns without starting anything unless the parent supplies its private root.
Every peer operation and child lifetime has a deadline; successful scenarios
explicitly kill/reap their child, with kill-on-drop protection on failures.

## Evidence and remaining scope

Tested producer: `b9469e8d08634bd8f576911ef7d2238f131f15e3`.
Frontend test source: `d7a3a5e530a0fd350075f1ca85e3f83539dc6089` (this stage adds
only this evidence document). Frozen framework:
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`; update-daemon dependency:
`7c3432f22ea82ebcd941f6ce8bcd562e2724d130`. Matching sibling-source preflight/
Nix development environments were used, without source overrides or lock updates.
Toolchain: Rust/Cargo 1.95.0, debug/unoptimized.

| Gate | Result |
| --- | --- |
| Explicit process test | Four SIGKILL/restart points passed |
| Exact input | 1,048,576 bytes accepted; 1,048,577 rejected before fake dispatch |
| Explicit service result | 16,777,216 API JSON bytes accepted; +1 bounded unknown, owner retained |
| Explicit event/writer | 33,554,432 bytes including LF accepted; +1 rejected; real stalled reader isolated |
| All-target producer tests | 223 library / 29 location / one idle-startup passed; five library + one location + one native-idle ignored in this ordinary run |
| Explicit heavy tests | Both ignored payload tests passed separately (five subcases total) |
| Strict all-target/all-feature Clippy and formatting | Passed |
| Actual Qt | 429 passed, zero failed, one existing RHI-renderer skip |

Native parent/child executable:
`bar-daemon/target/debug/deps/bar_daemon-f1cf32fffc46bb00`, SHA-256
`414cb94c4cefb9be5c6d2bc9a68777c1d5e7788aed497090d213dbf6091f27c0`.
This was freshly built in the assigned family, not reused from an original
checkout. Final logs (source snapshots, native results and binary/source hashes):
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/tasks/04-bar-runtime/artifacts/{producer-final,qml-final}.log`.

The first heavy run incorrectly expected a 32 MiB RPC result; it instead received
the existing bounded service error. The test was corrected to preserve and
qualify the actual 16 MiB boundary separately, not raise it. The first Qt run
failed before tests because an inherited GTK theme required a display; the
passing invocation used `QT_QPA_PLATFORMTHEME=generic QT_STYLE_OVERRIDE=Fusion`
only in the private test environment. Earlier failure logs are retained in the
task artifacts. No production defect or policy change was needed.

No fresh Quickshell probe, release package/Nix contract build, sustained-load or
performance measurement is claimed here. The prior native read/publication/
renewal probe remains separate prerequisite evidence.

### Scoped quality follow-up

Producer `4e84c74e2c6f0f26e09de106a92fdff9d06ceec5` consolidates acknowledged
battery receipt parsing in the private test client. One helper requires a successful
running receipt and returns its owned ID; the send-only lost-receipt case remains
separate. All kill points, owner/admission checks, payload boundaries and no-replay
assertions remain explicit. No production code or policy changed.

Pinned Rust Quality Lens `d28f3d936fa3c0d4c0a7ea753f436517077cb37d` captured
before/after evidence with an identical private authored-syntax scope/config.
Token clone lines changed **66 → 52** (six → five groups); the crash journey's
cyclomatic metric changed **66 → 63**, with cognitive complexity unchanged at 17.
These are review signals, not performance/correctness scores. All 41 reliability
findings and 10 test-quality findings remain visible. Three test-only unwraps
are misattributed as production in the narrow module inventory; no suppression
was added. Test-quality extraction remains **partial** on automatically included
baseline Wayland item macros, so this is not a full quality certification.

The affected producer/native suites and strict Clippy/formatting passed again,
including both explicit heavy suites. No QML changed; the prior 429-pass Qt run
is retained evidence, not a fresh quality-stage Qt invocation. Current native
parent/child executable SHA-256:
`aba4194bcd265e3b18fbb86cb1aefcd64eb7d0b9a5d04fe84d72c60d426ad32a`.
Raw configs, findings, comparison, command exits and verification log are under
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/tasks/04-bar-runtime/quality/`
(`before/analysis`, `after/analysis`, `comparison.json`, `verify-run.log`).
Coordinator/tooling-owner review is still required; all runtime qualification
limits below remain unchanged.

No production UI changes are required by this checkpoint. Existing battery
acknowledgement, display trial/draft/deferred-rollback ownership and historical
edge boundaries remain prerequisites, not new implementation. In particular,
this fixture does not qualify display persistence across an OS crash or prove
that a lost display receipt authorizes confirmation/rollback.

### Later serial measurement recipe (not run here)

Reserve the shared check lock for the entire measurement session; do not compare
runs collected while other workers build/test. Use the same frozen sibling
sources, pinned toolchain and release profile for both bridge and socket paths.
Drive a private fake-state runtime with the same ordered read/subscription/
renewal/cancellation workload, payload distribution, warmup and fixed sample
count (for example 1,000 warmup plus 10,000 measured requests per path). Alternate
path order across repeats. Record all producer/frontend/bridge process IDs,
source/binary hashes, raw per-request monotonic durations and serial
`/proc/PID/smaps_rollup` samples for every process in scope. Report p50/p99 and
RSS/PSS/private memory with sample counts and process sums; keep single-producer
and whole-family totals separate. A dedicated fixture/driver and approvals for
any broader environment are still needed. Do not infer these measurements from
this checkpoint's deadlines or test durations.

Remaining gates include packaged/production-entrypoint startup and crash recovery
with fake backends, real durable battery/display reconciliation, native frontend
process-crash and large-record recovery, broader terminal-delivery races,
sustained mixed load/bursts and measured memory, matched release p50/p99 and
RSS/PSS/private memory, upgrade/rollback, cold-start/default decisions and any
separately approved installed-session testing. Smoke/large-record passes do not
close sustained-load or release-performance acceptance.
