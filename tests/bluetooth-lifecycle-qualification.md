# Bluetooth lifecycle recovery checkpoint

Current focused repair: [consumer authority and same-device draft boundaries](bluetooth-consumer-authority.md)
records the 20261026T232107Z implementation, original negative witnesses and partial
acceptance (one obsolete out-of-scope Qt expectation remains red). Earlier
checkpoint/quality sections below are historical, not approval of the new repair.

## Scope and behavior

This tranche covers **caller-owned device operations**, not all Bluetooth
recovery. The bridge remains default; D-Bus and legacy clients remain supported.
There is no deployment, activation, hardware or installed-session acceptance.

The producer adds read-only `bluetooth.operation.status {request_id}` returning
`data.operation_status`. This differs from the `data.operation` admission receipt
so status reads cannot register/rebind accepted-work transport routes. An
abandoned cancellation RPC cannot abandon its accepted worker or terminal claim:
a separate reaper retains admission until the worker stops. Operation
status, operation records in `bluetooth.requests.snapshot`, and operation stream
content are caller-owned. An operation uses a never-reused UUID identity and an
exact positive per-operation `revision`; revisions are not delivery counters.
Active state, terminal retention and event publication transition atomically.
At most 64 terminal results survive five minutes; capacity eviction can be earlier.
Missing/foreign/expired outcomes are unknown, never success or permission to replay.
Cancellation waits for the worker to stop before releasing admission; it does not
roll back already-dispatched effects. D-Bus owner-loss cleanup now includes device
operations, including late registration during an existing cleanup window.

`BluetoothOperationRecovery.qml` merges revisions instead of replacing accepted
work from an aggregate list. It ignores unaccepted events (a pre-ack event is
repaired through owned status), stale/duplicate records, identity mismatches and
retired outcomes. Active operations are polled once per second, with only one
status read outstanding across the consumer. A read outstanding for five seconds,
a missing result or malformed/error status marks that operation explicitly unknown.
An overdue read is not replaced while outstanding. Healthy active operations have
no five-second operation lifetime limit. Unknown operations retain their device
busy guard and cannot reopen from late reads/events; they are conservatively
retained until transport reset rather than enabling an unsafe retry.

Status recovery does not restart a device operation, re-answer pairing, renew a
subscription, cancel a peer, or invoke the failed-pair rescan continuation. A
recovered terminal also avoids the event path's automatic radio read, since that
read can trigger the existing snapshot-driven scan policy. Radio observation
recovery remains separate through its cached read/watch. Existing
radio/audio watermarks remain prerequisites, unchanged. A radio-publication outage
no longer clears accepted operation guards. Background operation-status reads do
not count as foreground Bluetooth mutation requests. Pairing authority, private
input drafts, Enter/Tab save, Escape discard and existing explicit retries are not
replaced by operation ownership.

## Evidence owners

- Producer constructors/fixtures: `bt-daemon/src/daemon/operation.rs`,
  `bt-daemon/test_support/bt-api-v1.json` (`operation_ordering`).
- Producer tests: `src/daemon/operation/tests.rs`,
  `src/daemon/tests/socket/{operation,late_owner}.rs`; the existing socket cleanup
  test now proves device re-admission rather than treating a foreign empty snapshot
  as cleanup evidence.
- Generated BT bindings: `bluetooth/BtProtocol.generated.js`.
- Focused producer-generated Qt fixture: `tests/qml/fixtures/bt-operations.json`,
  checked by `tests/generate-bt-lifecycle-fixture.sh check`.
- Actual Qt: `tests/qml/tst_bluetooth_operations.qml`; existing ANC interaction
  coverage now supplies mandatory operation revisions.
- Narrow native Quickshell fixture: `tests/e2e/bluetooth-operations.qml`, driven
  only by the producer's explicit `bluetooth_operation_recovery_probe`. It omits
  operation event delivery from its subscription, reads active status, cancels one
  fake accepted operation, then requires terminal status recovery and retention of
  an unrelated synthetic prompt draft. Producer accounting requires zero active /
  exactly one retained terminal, proving no second admitted operation.

All native producer fixtures use an in-memory Bluetooth backend and private D-Bus
configuration with no host activation directories. The Quickshell child receives
private HOME/config/cache/runtime, offscreen rendering and unavailable host desktop
endpoints. This is an in-process exported producer, **not** a daemon OS-process
crash test. The old latency/memory probe is not invoked by this tranche.

## Inherited validation (archival, 2026-10-26)

This section records the earlier, withheld worker run, not fresh evidence for
this family's seeded sources. The current implementation/parity qualification is
recorded below; its mandatory quality continuation is still a separate gate.

Producer `54532b2b1d511cc3623a5ff109237ec4cbb6349c`, framework
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`; frontend is this checkpoint's changes
against `d7a3a5e530a0fd350075f1ca85e3f83539dc6089`. Full final frontend commit identity,
exact commands and logs accompany the worker report.

| Gate | Result |
| --- | --- |
| Producer all-target debug suite | 82 library + two private process integration passes; two explicit-only probes excluded normally |
| Focused native Quickshell operation probe | Explicitly passed twice on final operation implementation; final run follows the last frontend guard change; zero active / one retained terminal |
| Actual Qt 6.11.1 suite | 445 passed / zero failed / one existing renderer skip, including 14 lifecycle cases plus Qt hooks |
| Strict producer Clippy / formatting | All-target/all-feature Clippy with `-D warnings`, `cargo fmt --check` passed |
| Strict QML lint / generated checks | Passed; focused producer fixture and BT generated binding parity passed |
| Sibling-source capture / advisory panel review | Passed without source overrides or preflight bypass |
| Global BT contract fixture / full Nix package gates | Not accepted: existing global fixture needs coordinator regeneration; no package/release gate is claimed |

SHA-256 identities (all binaries were built/selected in this task family, not
borrowed from original checkout targets):

- Producer debug executable: `666ab057c404802ea5767cc718ec4e514ac5df9ad001ab2e8e3ca1c4b6d55274`.
- Native fake-producer unit-test executable: `e1f187f247102bb9358c18c2f991f383e8e8643faa7438f005c8e4db3594f8bd`.
- Quickshell 0.3.0 launcher: `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980`.
- Qt 6.11.1 qmltestrunner: `c52da9c0db18f2b81b298efa2435e7b828cf94dba06d08ba31f96c33e48ba83f`.

Initial attempts exposed a missing ambient Cargo toolchain, an untracked-input
preflight rejection, an incorrect cancellation-event expectation, two Clippy
findings, inherited GTK display initialization, and a Quickshell relative-import
root error. They were corrected and rerun, not counted as passes. The final native
controller also attempts an incidental bar bridge against the private,
no-activation bus and warns that `shelllist-search` is unavailable. Neither reaches
host services. This probe qualifies BT status/lifecycle recovery, not whole-panel
ranking, screenshots or a warning-free desktop session.

## Remaining lifecycle audit

| Row | Current authority / remaining work |
| --- | --- |
| Device operations | This tranche orders accepted IDs and repairs quiet terminal loss. Lost-before-ack identities and outcomes after daemon restart remain uncertain, not reconstructed from device state. Terminal history is not durable. Qualify sustained mixed load, bounded frontend tombstone growth and a deliberate UX for guarded unknown operations separately. |
| Aggregate requests | Only its operation records gain per-ID ordering. The aggregate is not an atomic cross-domain snapshot and has no global revision; absence never retires accepted operations. Pairing/scan observation races remain. |
| Pairing requested/display/answered/cancelled | `PairingBroker` remains the authority. Prompt IDs identify active broker requests; operation ownership is not response authority. Pending inputs expire after 60 seconds; snapshot `timeout_ms` is the original duration, not a refreshed remaining deadline. Display prompts follow BlueZ cancellation. Snapshot/event ordering, stale-after-answer/expiry resurrection, quiet terminal loss, observer/response authority and remaining-deadline metadata need their own producer/Qt tranche. Never restore a closed secret draft or answer during recovery. Existing UI-dismissal fences remain intact. |
| Scan started/completed/failed/cancelled | Caller-owned lease cancellation and shared-adapter retention already exist. Snapshots are unwatermarked active observations, with no retained outcome/status API or owner-filtered lifecycle ordering. Timeout cleanup can publish failed while retaining the lease and retrying cleanup; failed is not proof discovery stopped. Quiet expiry/event-loss and late aggregate restore need a separate lease/outcome model; do not replay scan acquisition as repair. |
| OBEX transfer/authorization | `bluetooth.obex.snapshot` is capabilities, not transfer status. Outgoing cancellation is owner-checked, but authoritative retained transfer outcomes/order metadata are absent. Incoming broker response authority and expiry must be audited independently; cancellation is not rollback of accepted files. Shelllist deliberately has no OBEX transfer UI/subscription, and this tranche does not add one. |
| Radio/audio | Completed full-state publication cursors are unchanged, except preserving operation guards during a radio outage. Their cached reads are not evidence of an uncertain device effect's completion. |

The existing scan-start/rescan policy in `BluetoothFlow.ts` and `applySnapshot`
remains a separate ownership audit. This tranche only prevents a recovered terminal
from invoking the event-only rescan continuation; it is not a broad Rust/QML
conversion. No shared Io/Core policy was privately forked.

## Current fixture-parity implementation (20261026T202406Z)

The current assignment explicitly includes the global BT contract. The inherited
fixture omitted `operation_ordering`, owner-private recovery compatibility and the
`bluetooth.operation.status` registry entry; its operation event also lacked the
native revision. `tests/generate-bt-lifecycle-fixture.sh` now renders/checks **all
BT companions** from the matching offline producer: the global API fixture,
focused operation fixture and generated protocol bindings. Before publishing, it
requires the producer's live constructor output to equal its checked producer
fixture. The binding still uses the unchanged shared generator, not a BT-private
policy fork. TypeScript/`BluetoothFlow.js` generation remains unchanged.

The actual Qt operation suite compares both fixture copies, the terminal status
and event, and every generated method/stream name. It also checks that status is
read-only/non-cancellable and owner identities are absent. The producer adds an
independent regression for the same status/event/retained-client correlation
boundary using its real serializer and `BluetoothCorrelation` implementation.
No production policy, pairing, scan, OBEX, shared Io/Core or transport default is
changed by this fixture closure.

### Fresh implementation qualification

All checks below ran through
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh`, with a
1,800-second outer deadline, private HOME/XDG, unavailable host desktop/bus
endpoints, two build workers and this family's sibling-source capture/preflight.
The task root is
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/01-bluetooth-recovery`.
Exact retained drivers are `producer-check.sh` and `frontend-check.sh` there;
`artifacts/source-capture.json` retains the eight-source graph and approval root.
Original baselines are Shelllist `6f14ede26d27cff03b72e51f647ee5e96dba6928` and
BT `3e0ecb4f81aeada42cd3623dedb7fa4d3c46995f`; inherited applied heads are
Shelllist `68694be751959d2e4d6a1ebde7fbb2d77f108a47` and
BT `a5869d8827ebacae0b2f0c6c3848128952857f2d`, not approved integration.
Framework remains `563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`.

| Fresh gate | Result / task-root-relative evidence |
| --- | --- |
| Producer all-target debug tests; formatting; strict all-target/all-feature Clippy | 83 library + two private process passes, two explicit-only probes normally ignored; all strict checks passed (`producer-final.log`) |
| Inherited global fixture negative | Generator diff rejected missing operation metadata/registry; actual Qt parity test failed on absent `operation_ordering` (`stale-fixture-negative.log`, `stale-fixture-qt-negative.log`). Both are intentional retained negatives, corrected before final passes. |
| Full BT companion parity / offline contract | Producer input, global fixture, focused fixture and shared-generated binding match; `cargo xtask contract bt --bin <matching-family-binary>` passed (`frontend-check.log`) |
| Generator safety / language checks | Bash syntax, ShellCheck and `check-bt-fixture-generation.sh` passed: stale/missing inputs, partial failed rendering without publication, generation and independent drift in all three outputs. Synthetic executables test orchestration only; actual parity uses the real producer/shared generator. Embedded Python is exercised here, not certified by Rust/QML lenses. |
| Frontend static/generated gates | Strict QML lint including both native BT fixtures, TypeScript generated-output check, shared generated-contract negatives, surface catalog, build-input and advisory panel review passed (`frontend-check.log`). No new UI role/geometry exceptions. |
| Actual Qt 6.11.1 | **472 passed, zero failed, one existing software-renderer artwork skip** (`frontend-check.log`) |
| Actual Quickshell 0.3.0 operation probe | Explicit lifecycle-only case passed, zero active / exactly one retained terminal (`artifacts/bt-operation-native.json`). The older benchmark was not invoked. |
| Sibling-source Nix | `btDaemonContract`, `qmlTests`, `buildInputs`, `btDaemonPackage` passed (`nix-<attribute>.log`); release BT tests: 83 library + two private process passes, same two intentional ignores. Nix Qt: 472 passes / one existing skip. |

The refreshed global fixture and checked producer input are byte-identical,
SHA-256 `402f15f77c8d0b7c81e70b1bff04cc1c87ecd1a875d148ba184debd7d5155d84`.
Current binary SHA-256 values (full paths in `artifacts/binary-sha256.txt`):

- Family debug producer: `995cedd3fd8868c0608e0f27c882b9789bc054a9b41732d4956c990c1492aa6f`.
- Cargo-reported native lib-test executable: `d30351bfec0ae3cbdab43af03c09fe6e0a8b24084d81afa882fd46ab6be9a896`.
- Shared protocol generator: `7c6f356a4c024080ca62d319f7ec68e83314b55ed6ae8275cdba9dba7b0cf6b3`.
- Nix release producer: `e5ea5438c89890d775f034e468eb6c3b4b415b5c249ab8f632213326ea1e6b59`,
  `/nix/store/97rk8d15ijmm3hlkj4fafdkl4qx98nbi-bt-daemon-0.1.0/bin/bt-daemon`.

Qt/Quickshell binary hashes match the archival values above; these were freshly
hashed, not reused as evidence. Rust/Cargo are 1.95.0. Native JSON additionally
seals the executed backend/recovery/binding/probe source. Native limitations above
still apply: an in-process fake backend/private no-activation bus, not producer
SIGKILL or hardware; incidental bar-bridge retries and absent search executable
remain private warnings, not whole-panel acceptance. No deployment, installed
profile changes or final latency/memory measurements occurred. The task's
`SERIAL-RELEASE-RECIPE.md` supplies the queued matched-release recipe for a later,
coordinator-confirmed idle window.

Reproduce the final checks from `worktrees/` (with `ORCHESTRATION_TASK_DIR` set):

```sh
/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh timeout 1800 \
  nix develop ./daemon-framework --no-write-lock-file -c bash -c \
  './daemon-framework/tools/local-build preflight ./shelllist && ./daemon-framework/tools/local-build develop ./shelllist --command bash "$ORCHESTRATION_TASK_DIR/frontend-check.sh"'
```

The first executed batch additionally set `BT_EXPECT_INHERITED_DRIFT=1` to retain
both negative witnesses before regeneration; omit that flag on corrected HEAD.
Only qualification documentation was updated after the executable checks; runtime,
test, fixture and generator inputs are unchanged. This is an **implementation
handoff**, not completed Rust/QML quality review or coordinator approval. The
mandatory exact-session continuation must inventory the full original-baseline
diff, including inherited code/tests/fixtures/generators, and perform fresh Rust
extraction plus QML BEFORE/AFTER review. Pinned locked helper compilation in its
private cache is explicitly authorized; the previous missing extraction is not
waived by these functional passes.

### Dependent lane contracts still required

The remaining lifecycle table above is unchanged. W2-BT must separately settle
pairing observation versus response authority, ordered prompt membership and
remaining expiry; scan retained status/lease cleanup versus terminal outcome;
and aggregate cross-domain recovery boundaries. External-client OBEX outcome
retention/authorization is another tranche, not a new Shelllist transfer UI.
CQ-02 requires those operation/scan/prompt prerequisites before adding a native
rescan recommendation that read recovery cannot execute. CQ-03 still requires
native scope/ranking/disambiguation/effective-policy facts with draft/selection
regressions. Neither conversion is authorized by this checkpoint. Lost acceptance,
retired owners, guarded unknown work, stalled reads, non-durable restart outcomes,
retained-stdio lifecycle coverage, payload/load/startup/upgrade/rollback and serial
release measurements remain explicitly open; no absence-based success or replay.

## Reproduction

Use the family's sibling-source `daemon-framework/tools/local-build` and matching
development environments. Every heavy invocation must be wrapped with the
orchestration `check.sh`; set bounded deadlines. Stage new tracked inputs with
`git add -N` before source snapshots. The report gives exact executed commands.

Producer gates: `cargo test --locked --all-targets -- --test-threads=1`, strict
all-target Clippy and `cargo fmt --check`; rebuild `bt-daemon`, regenerate/check
its frozen producer contract and the focused frontend fixture/bindings. Frontend
gates: strict QML lint and actual Qt suite. Explicit native probe (inside the
matching Qt/Quickshell environment, using the freshly built unit-test executable):

```
SHELLLIST_SOURCE=/absolute/family/shelllist \
BT_DAEMON_BIN=/absolute/family/bt-daemon/target/debug/bt-daemon \
BT_OPERATION_REPORT=/absolute/private/task/artifacts/bt-operation-native.json \
/absolute/family/bt-daemon/target/debug/deps/bt_daemon-<matching-hash> \
  --exact daemon::tests::socket::probe::bluetooth_operation_recovery_probe \
  --ignored --nocapture
```

Do not run this QML fixture standalone against a real service. Do not invoke the
older full benchmark amid concurrent workers. Final matched release measurements,
OS-process crash, startup, upgrade/rollback and any rollout remain separate gates.

## Fresh full-baseline quality continuation

The exact implementation session resumed at clean BT `a7d275a` / Shelllist
`208789b`, retaining the original **13 + 15 file** diff bases and all inherited
source/tests/fixtures/generators. This section supersedes the implementation's
pending-quality paragraph only; it does not complete the remaining lifecycle rows
or confer integration approval. Raw current evidence is under this task's
`quality/`; its immutable implementation handoff remains in
`quality/implementation/`.

Pinned QML Lens source `97feb1f`, dist SHA-256
`b6443d1f0b8a610f73c79926080245e718f53ebaa0d903639bfb44df497b2a85`, and
RQLens source `d28f3d9`, CLI SHA-256
`622b2c793a574781cd40a190a457f58af4b8c222ee5efce04c4e77488c50929a`, remain
read-only. Task configs disable all execution adapters/imported runtime reports;
project runtime/profiling configs were inspected, not blindly executed. The Rust
helpers were actually compiled with the unchanged analyzer's normal **locked**
dispatcher from the exact pinned helper manifest into a private task cache, as
explicitly authorized. No main CLI/tool source/lock changes or substitutions.

Fresh QML BEFORE/AFTER static producers are `quality.qml`, `quality.hotspots`,
`quality.clones`, `correctness.catalog`, `quality.semantic_rules`; Rust uses
hotspots, clones, reliability, escape-hatches, type-health, test-quality,
architecture-rules and map. Same config bytes, producers and source scope are
retained for comparable runs. No measure-all, verify/audit/coverage campaign,
compiler expansion, live runtime or performance measurement was run by the lenses.
Actual project tests/native checks are independent private verification.

### Reviewed findings and no-code-refactor decision

- QML: 38 files (32 QML/five JS/qmldir), 4,897 lines, 366 functions and 1,028
  bindings; zero parser diagnostics and complete authored-syntax complexity.
  **209 review findings remain**, including 11 normalized clone groups; there
  are also three structural clone groups. Resolution is partial: 27 unresolved
  imports, 78 unknown types and 546 skipped semantic evaluations. Qt success does
  not certify those abstaining rules or external type hierarchies.
- Recovery `apply` is 12/13 and `finishStatus` 11/10 cyclomatic/cognitive. Their
  ownership, identity, revision, terminal/unknown and outstanding-read checks are
  distinct safety boundaries. `clearStatusRead()` already centralizes the safe
  retirement transaction; the uncertainty deadline must not clear it or overlap
  reads. Keep the linear eight-line native wire predicate (12/11), not per-field
  helpers that hide the boundary.
- The inherited named native fixture phases remain 23/32. Further mechanical
  splitting would obscure single-admission/cancellation and terminal/draft checks.
  Test/setup clone observations do not prove redundant behavioral protection.
  Dynamic malformed-DTO helpers and broader pre-existing binding/API annotations
  remain advisory, not a reason to narrow tests or port UI transactions to Rust.
- Rust: 78 syntax files, 991 hotspot records, 45 clone groups, 450 reliability
  observations, two intentionally ignored probe observations. The operation code
  is bounded (admission 6/4, cancellation 3/2). Its new checked lookup invariant is
  proven under a single mutex without await/mutation; existing offline fixture
  invariants and test unwraps are retained rather than converted to silent failure.
- Rust extraction is no longer missing, but **remains semantically partial**:
  seven unexpanded item macros, 186 observed type rows with 130 resolved/four
  unresolved explicit impl joins and 1,854 type limitation reasons, plus 861
  unresolved semantic references. The map lacks unrequested locality/leverage/
  correctness inputs. One configured error-level architecture observation remains:
  protocol → daemon for canonical offline fixture constructors, an edge already
  present at original baseline. No rule, threshold or exclusion was relaxed;
  coordinator contract-boundary disposition is still required.

**Evidence-backed no-additional-code-refactor** is the reviewed decision, not a
zero-finding claim. No safety test is removed, warning suppressed or score gamed;
all implementation program/test/fixture/generator bytes remain unchanged. The
quality commits contain scoped durable evidence/rationale in the two existing BT
qualification contracts. `quality/TRIAGE.md` and `quality/comparison.json` record
retained versus introduced findings, exact identities and limitations. Comparable
AFTER is repeated at clean quality heads, not borrowed from the old withheld run.
The local comparison initially stopped on volatile Rust `measured_at` timestamps
following passing checks/producers; its raw failure/artifacts are retained. Only
measurement timestamps/provenance are normalized, not findings/metrics or policy.

### Functional and language verification

The task's `quality/verify.sh` reruns producer tests/formatting/strict Clippy and a
matching build, actual Qt/native recovery, all BT companion/offline parity, strict
QML/native-fixture lint, Bash syntax/ShellCheck/generator failure-safety tests,
TypeScript generated-output compilation, shared generated negatives, surface and
build-input checks, and sibling-source Nix BT contract/package/Qt/build-input
checks. All heavy work uses the current required `check.sh timeout 1800` private
shared lock and matching family capture/dev shells. Raw command exits, counts,
logs, source capture and binary hashes are retained under `quality/` and summarized
in its report, not inferred from the static scores. Both shell scripts and embedded
Python were also manually reviewed; neither lens certifies Bash/Python/TypeScript
or Nix. Generator rendering validates inputs before copying, but is not an
fsync/multi-file filesystem transaction; copy failure must remain detectable by
parity checks.

Safety/remaining acceptance boundaries above remain unchanged. The native fixture
is in-process/fake-backed/private no-activation D-Bus, not hardware or producer
SIGKILL; private bar/search warnings and the software-renderer artwork skip remain
explicit. No deployment, profile installation, default change or final benchmark.
The serial matched-release recipe remains queued for an idle coordinator-approved
window. This is partial quality evidence for coordinator review, not rollout or
integration approval.
