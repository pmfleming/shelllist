# Bluetooth consumer authority repair — 20261026T232107Z

**Repair checkpoint; functional acceptance and static evidence remain partial.**
The quality continuation below supersedes the implementation's pending-review
statement, not its retained failures. No integration, rollout, startup or deployment approval. The bridge remains default.
Inherited seeds and their earlier evidence remain unapproved inputs; this record
supersedes their consumer-authority claims, not their immutable negative witnesses.

## Authority and transaction boundary

- `BluetoothOperationRecovery.restore` validates the whole operation collection,
  then reconciles **only IDs acknowledged to this consumer**. Transport-owner
  aggregate visibility is not a local admission receipt. Unknown active/recent
  peer rows neither populate cancellation authority nor create retirement fences.
  Pre-ack observations remain repairable by status after the actual receipt.
- Known local IDs still merge increasing, identity-matching revisions. Aggregate
  absence remains unknown; terminal/uncertainty fences, single outstanding status
  reads, device admission guards and explicit retry/no-replay behavior are retained.
- Neither live nor recovered operation completion identifies a pairing prompt.
  Device equality, timing and shared-owner membership establish no causal relation.
  Operation handling no longer calls device-key prompt closure. Actual prompt-ID
  lifecycle events and captured pairing-response acknowledgements still close
  their own prompt and clear only its draft. A late response cannot close the next
  same-device prompt. No new prompt-operation relation or Rust policy was invented.
- Producer runtime, protocol/schema, fixtures, bindings, generators, shared Io/Core,
  scan/pairing/OBEX policy and all ordinary editing transactions remain unchanged.

Executable repair paths are `bluetooth/BluetoothOperation{Recovery,Controller}.qml`.
Existing Qt/native probes are extended, not replaced with a parallel transport.
The producer change is test-only `src/daemon/tests/socket/probe.rs` provenance and
completion assertions; its runtime and serialized fixture bytes are unchanged.

## Regressions and focused checks

The coordinator's exact two diagnostics were copied into the existing operation
suite **before** the repair. Fresh Qt 6.11.1 reproduces both: peer cancellation
returns true, and the separate same-device draft becomes empty. Retained
`negative-qt.log` has two passing hooks/two failures, Qt exit 2 (local-build wraps
this as exit 1). No real effect or secret was involved.

Nearby cases cover active/recent aggregates before acknowledgement, known-local
revision reconciliation/cancellation, peer-ID exclusion, terminal/no-replay fences,
and live/status/aggregate × completed/failed/cancelled prompt retention. Positive
prompt-ID cancellation and late captured-response handling remain executable.
The focused suite passes **31/31**, including hooks. Existing single-flight status,
quiet loss, malformed identity/revision, uncertainty, peer and reconnect cases pass.

The private native probe now uses **two logical consumers on one socket owner**.
The peer's production owner-filtered aggregate contains the first consumer's active
and retained-terminal IDs, proving shared-owner visibility without exporting owner
identities. Its local operation map stays empty and cancellation is rejected. The
acknowledged consumer can still cancel; its omitted terminal event is recovered
through owned status while its same-device synthetic prompt/draft survives. After
that consumer is destroyed, the peer completes fresh reads and still cannot adopt
terminal history. Producer accounting is zero active/exactly one retained result.
Two corrected serial repetitions pass. This is correctness, not a measurement.

An initial repeat failed because a late-created peer briefly subscribed to operation
events, defeating withheld-terminal delivery. The fixture now creates/configures
both consumers before asynchronous connection readiness. The failed report/log is
retained separately; no production subscription or routing policy was changed.

## Fresh matched checks and remaining blocker

Task root (all relative artifact/log names below resolve here):
`/home/laufan/Projects/shelllist-orchestration/20261026T232107Z/tasks/01-bluetooth-authority-repair`.

| Gate | Result / retained evidence |
| --- | --- |
| Producer fmt, all-target tests, all-target/all-feature strict Clippy, fresh debug binary | Pass: 83 library + two private process tests; two explicit-only probes normally ignored (`producer-check.log`) |
| Producer fixture serialization | Fresh `debug contract-fixture` equals checked producer fixture byte-for-byte; no fixture write |
| Existing BT generator checks/language checks, generated contracts/TypeScript parity, offline BT contract | Pass (`frontend-final.log`): Bash syntax, ShellCheck, generator negative/drift suite, all BT companions, actual producer/shared generator; no generator/schema edits |
| QML lint, surfaces, build inputs, advisory panel review | Pass, including native probe; zero new panel numeric/wrapper prompts (`frontend-final.log`, `matching-check.log`) |
| Focused actual Qt | 31 passed, zero failed (`repaired-qt-focused-2.log`) |
| Full actual Qt | **499 passed, one failed, one existing renderer skip** (`frontend-final.log`) |
| Native Quickshell 0.3.0 | Two passes (`artifacts/bt-operation-native-final-{1,2}.json`) |
| Sibling-source Nix | `btDaemonContract` and `buildInputs` pass; `qmlTests` reproduces exactly the same single obsolete test failure (`nix-*.log`) |

### Explicit coordinator scope request (not silently waived)

`tests/qml/tst_bluetooth_stream_recovery.qml:117–126` assumes operation completion
may close its device's prompt, then expects a newly appended `other-prompt` to be
first. With the required repair the independent original `prompt` correctly
survives; line 126 observes `prompt`, expected `other-prompt`. This file is **not in
this assignment's manifest allowlist**. It was not edited and the suite was not
filtered/skipped or policy weakened to make the result green.

Requested coordinator change: first assert `fixture-draft`/`prompt` survived the
operation and scan observations, then explicitly close `prompt` by a prompt-ID
`cancelled` event before the existing distinct-prompt snapshot checks. The proposed
scoped patch is task-local `requested-stream-test-update.patch`, not applied code.
Until authorized/reviewed, full Qt and Nix Qt acceptance remain failed, not passed.

## Provenance, safety and reproduction

Source graph/captured approval root: `artifacts/source-capture.json` and
`artifacts/implementation-sources/sources.json`. Original quality bases are BT
`3e0ecb4f81aeada42cd3623dedb7fa4d3c46995f` and Shelllist
`ecf9819fbfbe2cc55e33cd920f3be138602ccf8d`. Applied seed heads are respectively
`fc28f83a4f9fc49a250158c59f9c4d8e847f43e9` and
`226028b22b6bf0fa2a41508c6d33fedcbb2e7092`. All eight frozen family heads remain
recorded in the run manifest; no dependency source/Git state was modified.

Binary SHA-256 (`artifacts/binary-sha256.txt`; Rust/Cargo 1.95.0):

- Debug producer: `499bca20d87244bf09f069f12628385747987acb923898ce9044fa4da4c760b7`.
- Native lib-test: `6fe5403a93eb05d6339cc75124c2feefe6b0d366dafa833cea7c2ec8b1f35689`.
- Matching shared generator: `0f853eb234f4caa55c08a281b1d74d14dfb9d2d769ca58e687941beb1a24e380`.
- Qt runner: `c52da9c0db18f2b81b298efa2435e7b828cf94dba06d08ba31f96c33e48ba83f`.
- Quickshell launcher: `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980`.

Exact retained drivers are `producer-check.sh`, `frontend-check.sh` and
`matching-check.sh`; no old artifact-overwriting drivers were executed. From this
family's `worktrees/`, with `ORCHESTRATION_TASK_DIR` set to the task root:

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T232107Z/check.sh
$CHECK timeout 1800 nix develop ./daemon-framework --no-write-lock-file -c bash -c \
  './daemon-framework/tools/local-build preflight ./shelllist && ./daemon-framework/tools/local-build develop ./bt-daemon --command bash "$ORCHESTRATION_TASK_DIR/producer-check.sh"'
$CHECK timeout 1800 nix develop ./daemon-framework --no-write-lock-file -c bash -c \
  './daemon-framework/tools/local-build develop ./shelllist --command bash "$ORCHESTRATION_TASK_DIR/frontend-check.sh"'
# matching-check.sh captures a persistent source graph (destination must be new),
# then separately records contract/buildInputs/qmlTests exits; Qt is currently red.
$CHECK timeout 1800 nix develop ./daemon-framework --no-write-lock-file -c bash -c \
  './daemon-framework/tools/local-build develop ./shelllist --command bash "$ORCHESTRATION_TASK_DIR/matching-check.sh"'
```

Every heavy check used this helper's shared lock/private HOME/XDG/unavailable host
buses/compositor and matching sibling-source capture/preflight. Constructors were
inspected: the native producer uses `Rig`/`TestBackend`, in-memory pairing/settings
and a private bus config with no service directories/activation helper. No real
BlueZ/audio/OBEX client, hardware, clipboard, catalog/windows, notifications, manager
or installed service was exercised. Child work is bounded and awaited. Native
logs retain missing-search, incidental private bar-bridge retries and startup
request-ID warnings: this is not warning-free whole-panel/startup acceptance.

The configured `data-contracts-independent-of-hardware` protocol→daemon finding
remains visible **retained bounded architecture debt, not a rule pass** under the
prior coordinator's offline-fixture disposition. These constructor paths/rule are
unchanged. No contract relocation, policy tuning or private policy fork occurred.

Mandatory next phase: supervisor resumes the exact exited session for a FULL
original-baseline Rust **and** QML BEFORE/AFTER quality loop, including all inherited
seeds/tests/generators/generated companions; triage/refactor-or-retain rationale,
affected checks and a separate nonempty quality commit. No quality certification
is claimed here. W2 pairing/scan/aggregate/OBEX lifecycle, CQ-02/03, lost-acceptance,
retired-owner/restart uncertainty, payload/load/startup/upgrade and serial release
measurements remain outside this repair. The task's `SERIAL-RELEASE-RECIPE.md`
retains a later exclusive matched-release recipe; no benchmark ran here.

## Exact-session quality continuation — 20261026T232107Z

The same Sol 6.1/high session resumed after implementation exit at BT `77f9027` /
Shelllist `7e032ea`. Full original-main-baseline inventory is **13 BT + 16 Shelllist
paths**, including every inherited seed, test, generator, JSON fixture and generated
JS/qmldir companion; no implementation history was rewritten. Task-local
`quality/full-baseline-inventory.json` seals paths/hashes and both full diffs.

Fresh pinned RQLens (`d28f3d9`, unchanged CLI SHA-256
`622b2c793a574781cd40a190a457f58af4b8c222ee5efce04c4e77488c50929a`) and
QML Lens (`97feb1f`, unchanged dist CLI SHA-256
`b6443d1f0b8a610f73c79926080245e718f53ebaa0d903639bfb44df497b2a85`)
ran named static producers in owned configs, with the same scope/configs on BEFORE
and AFTER. The normal analyzer-managed **locked extraction-helper build** used the
pinned `rust_helpers/Cargo.toml` and this task's private cache; no tool source/main
CLI/lock was changed, installed or replaced. Project runtime/test/profiling adapters
were inspected but not enabled in Lens. No measure-all, audit, coverage, macro
expansion or benchmark campaign ran. Raw artifacts/commands/provenance and manual
triage remain in `quality/{before,after}`, `quality/TRIAGE.md` and
`quality/comparison-before-after.json`; all **18** findings/metrics artifacts are
identical after explicitly removing only timestamps, invocation/fingerprint/cache
metadata. Raw hashes and source/config/tool/helper identities remain separate.

**Partial extraction, not a blanket pass:** Rust inventories 78 authored files,
991 hotspots, 45 clone groups and 450 reliability observations; seven unexpanded
item macros remain. Bounded offline rust-analyzer with build scripts/proc macros
disabled resolves 838/861 collected references; **23 unindexed project definitions
remain unresolved**. Type-health's 186 rows/130 resolved/four unresolved explicit
impl joins retain null compiled totals. QML inventories 38 files, 374 functions and
1,040 bindings, with zero parser diagnostics but **27 unresolved imports, 78 unknown
types and 548 skipped evaluations**. Static test discovery is not executed-test
attribution. No unknown type/API was guessed or suppressed to get green evidence.

**No extra code refactor is justified.** Recovery's validation, captured-target,
revision/terminal/uncertainty and single-flight guards are the behavior being
protected. The native phase handler is a high-complexity hotspot (46/65
cyclomatic/cognitive), but its cohesive bounded sequence makes the ownership and
no-replay proof visible; arbitrary helper/timer splitting would only game metrics.
Controller/backend size/missing-annotation/binding notices span legitimate existing
editing/navigation/domain transactions. Clone similarity between producer, Qt and
native tests protects distinct serialization, transaction and routing risks; no
distinct test was removed. These findings remain raw, not recategorized as solved.
The protocol→daemon error and bounded offline-fixture debt disposition remain
unchanged and visible; no architecture rule or analysis threshold was tuned.

Fresh affected verification (`quality/validation.log`, drivers
`quality/verify-{producer,frontend}.sh`) passes formatting, 83 library + two private
process tests, strict all-target/all-feature Clippy, matching producer build/fixture,
generated companions/contracts/TypeScript, Bash syntax/ShellCheck and existing
Python-embedded generator negative/drift tests, strict QML lint, surfaces/build
inputs and advisory panel review. Two more exact native operation probes pass with
zero active/one retained terminal; focused Qt passes **31/31**. Full Qt remains
**499 passed / one failed / one existing renderer skip**, and matching Nix Qt
repeats that failure; Nix BT contract/buildInputs pass. The obsolete out-of-scope
stream test and unapplied coordinator scope request above are **not closed**.
Neither Lens certifies shell/Python/TypeScript orchestration: the named existing
language checks exercise it, without claiming complete static language analysis.

This separate nonempty quality evidence commit preserves every executable,
fixture/generator and interaction byte from implementation. Final clean-head
static extraction, source/binary hashes, exact exits/logs and remaining acceptance
are sealed in task `quality/REPORT.md` and `quality/result.json`. Overall/quality
status remains partial; coordinator semantic review and the explicit test-scope
resolution are still required. Broader lifecycle, startup, release measurement and
rollout remain outside this checkpoint; bridge default and retained clients remain.
