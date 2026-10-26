# Clipboard private OS-process crash/restart qualification

Scope: test-only exported clipboard daemon service, not production activation,
installed-session acceptance, hardware, load or performance qualification. The
bridge remains the default; D-Bus and legacy clients remain supported. Existing
128 MiB/32 MiB framing and stalled-reader evidence is not repeated here.

## Fixture and safety boundary

Producer: `clip-daemon/src/daemon/socket/tests/process.rs`, registered by
`src/daemon/socket/tests.rs`. The test executable re-execs exactly one acceptance
test under a private child marker. That child constructs the real `ClipDaemon`,
`ApiService`, `Owners`, production socket `Service`, correlation/configuration and
shared listener. Requests traverse real admission, validation, operation book,
owner cleanup and subscription delivery. It is a separate OS process killed with
SIGKILL, not listener recreation or an in-process service teardown.

All async capture work is an independent in-memory backend with authoritative
status snapshots. It deliberately does **not** use `FakeBackend::with_operations`
(which internally constructs Ringboard). Only inert history/edit/publication
methods delegate to `FakeBackend::with_entries`. Settings use isolated state,
no services and unavailable capture control. No Ringboard/capture worker or live
clipboard backend is initialized. There is no production test switch or new API.

The parent starts and reaps a no-activation private D-Bus daemon using the existing
`test_support/owner-session.conf`, without host service directories. The child
clears its environment, uses private HOME/config/cache/data/state/runtime paths,
explicitly mode-0700 canonical runtime directories, nonexistent host bus/Wayland
endpoints and a PATH containing **only** a generated `hyprctl` fake. That fake uses
an absolute shell interpreter and shell builtins: it returns a fixed synthetic
window and records fake focus/input injection. It never connects to a compositor,
executes a host helper, publishes clipboard data or sends a notification.

Each daemon child has a 40-second lifetime ceiling; parent crash/admission tests
have 60/40-second deadlines. Bus startup, markers and socket reads are bounded by
five seconds. Parent guards SIGKILL and reap daemon/bus children on failure too.
Gates and audit records contain synthetic identities/status only, never user data.
Control markers are atomically renamed. The child is still holding the real
accepted work when a post-dispatch gate withholds a receipt from the listener.

## Acceptance cases

| Phase | Crash position and assertions |
| --- | --- |
| `pre-ack` | Capture accepted/owned but no response delivered. Exact ID is available only to the test oracle; reconnect cannot recover it even when supplied. |
| `accepted` | Capture acceptance delivered, fake committing work still active. Owner/peer status and cancellation authorization checked before SIGKILL. |
| `terminal-receipt` | Authoritative backend terminal snapshot exists; its status response is withheld before transport delivery. Restart reports unknown, not inferred completion. |
| `terminal-event` | Real subscribed terminal event received before SIGKILL. New owner still cannot read the retired producer's non-durable outcome. |
| `publication` | Fake copy/publication completed, synchronous receipt withheld. Recovery reads do not repeat publication. |
| `paste-prepared` | Fake publication completed and original session armed; preparation receipt withheld. No hidden acknowledgement, therefore no fake input. |
| `paste-hidden` | Real single-use hidden handling schedules its delayed task, but the hidden response is withheld. SIGKILL occurs before observed fake input; restart never reschedules it. |
| `paste-delivered` | Fake input actually observed once; repeated hidden rejected. Restart neither republishes nor injects again. |

Restart uses the same runtime and stale socket left by SIGKILL. Both former peer
connections reach EOF. Fresh history baselines have a new producer epoch; socket
owners do not inherit old ownership. Exact old operation IDs, edit leases and
paste-session authority are rejected. Missing/non-durable outcome evidence is
explicit `operation-unknown`, never success or permission to retry an effect.
Only a separately requested new capture starts new work; a surviving peer remains
usable when another new consumer disconnects.

The separate admission test fills 64 globally active fake committing operations
(16 per owner). Disconnect requests cancellation but the backend cannot roll back
committing work. Replacement ownership remains globally busy until authoritative
terminal snapshots release those slots; other owners' work remains active. It
also verifies the per-owner busy limit and foreign-owner status rejection.

## Actual Qt coverage

`tests/qml/tst_clipboard_process_crash.qml` uses the real clipboard controllers,
recovery policy and shared `DaemonSessions` generation routing with a recording
transport. It complements, rather than impersonates, the real producer processes.

- A lost save retains the private draft and clears old paste intent. Recovery
  opens fresh sessions/baselines for both consumers, not another save or effect.
- Explicit retry obtains a fresh lease. A late old-generation receipt with the
  same local `edit-commit` ID cannot consume the new pending request, clear its
  draft or send a hidden acknowledgement for the retired session.
- Before-ack, accepted and delivered-terminal operation cases reject retired
  acceptance/event/subscription records after reconnect. New explicit work stays
  active; another consumer's draft and operation ownership remain separate.

Existing keyboard interaction/save/discard tests remain in the full Qt suite.
No production QML or shared Io/Core implementation changes are required.

## Reproduction

From the isolated sibling-family root, with the orchestration task environment:

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/check.sh

"$CHECK" timeout 600 nix develop ./daemon-framework --no-write-lock-file \
  -c ./daemon-framework/tools/local-build develop ./clip-daemon --command \
  bash -c 'cd clip-daemon && cargo test --locked --lib daemon::socket::tests::process -- --nocapture'

"$CHECK" timeout 900 nix develop ./daemon-framework --no-write-lock-file \
  -c ./daemon-framework/tools/local-build develop ./shelllist --command \
  bash -c 'cd shelllist && export QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE= QT_QUICK_CONTROLS_STYLE=Basic; tests/run-qml-tests.sh'
```

Use the family's framework local-build capture/preflight. Stage new inputs with
`git add -N` before snapshot commands; do not override sources or update locks.
Clearing the inherited GTK platform theme is necessary for private offscreen Qt
on hosts that otherwise initialize a display-dependent GTK theme.

## Evidence and limits

Qualification run identities/results are recorded in the task's `REPORT.md` and
artifact logs. Baselines: clipboard `80ffa46de5346f4599a4af79ce0b7caa488c142e`,
Shelllist `d7a3a5e530a0fd350075f1ca85e3f83539dc6089`, framework
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`. New commits contain only scoped test
and evidence additions.

Actual Qt rerun: **435 passed, zero failed, one existing renderer skip**, including
all four new data-expanded clipboard generation/draft cases. Initial GTK theme
failure was environmental, not counted as a pass.

Producer commit: `510d55775028de5c79fcf5847db2b3b6daba243a`. Both process tests
passed, with all eight phases, then passed **three serial repeat runs**. Formatting
and strict all-target/all-feature Clippy passed. QML lint passed. The full producer
suite and package/release checks were not rerun for this test-only tranche.

Native debug executable:
`clip-daemon/target/debug/deps/clip_daemon-4f2bffa997e4a53b`, built here with
`rustc 1.95.0 (59807616e 2026-04-14)`, ELF SHA256
`1983014ee38a731e57a4a1232ef0b5ca00ab9c3fa2e69c6911af42b3477b825b`.
Process-test source SHA256:
`52fc4b4f929a9d52a634ead053ff646752e907f5ac7f0138a94b642f216200fd`.
Qt test source SHA256:
`eab77e7b04736850b4849516dcb482d0f20317aa8be4054ba5c1b630665e45ce`.
QtTest/Qt 6.11.1 runner:
`/nix/store/b6j7b0rnw3fxj8d117icwvvymw91sycl-qtdeclarative-6.11.1/bin/qmltestrunner`,
ELF SHA256 `c52da9c0db18f2b81b298efa2435e7b828cf94dba06d08ba31f96c33e48ba83f`.

Logs under
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/tasks/03-clipboard-crash/artifacts/`:
`process-fourth.log`, `process-final.log`, `qml-second.log`, `qml-lint.log`.
Earlier failed fixture/environment attempts remain recorded in the task report;
none are counted as passes.

This is not the packaged daemon main/startup path, a durable journal, an actual
clipboard/capture/desktop effect, or one combined Quickshell-plus-producer crash
run. Terminal status-delivery withholding is at a deterministic pre-send boundary,
not arbitrary byte-level kill timing. Fake input cancellation before observation
is not a guarantee of rollback once a real effect may have started. No release
latency/RSS measurements, sustained mixed load, full startup/upgrade/rollback,
installed-session/default rollout or live service acceptance is claimed.

## Authorized quality check/refactor

The implementation identities above remain historical evidence. The follow-up
used pinned Rust Quality Lens and qmlqualitylens with fixed private static-only
configs; no runtime/profiling/coverage/measure-all or tool verification commands
were enabled. BEFORE/AFTER artifacts, triage and exact commands are in this task's
`quality/` directory. Native functional checks are separate from lens findings.

Producer quality commit `cbbd97d33c0add815241a0534f9e3a824108e732` centralizes
private process/bus/runtime ownership in `ProcessFixture`, with explicit field
cleanup order and a stopped-child requirement before restart. Failure diagnostics
now bound the log read itself to 4096 bytes, not just the displayed string. No
crash phase or authority/admission assertion was removed. Token-clone observations
went from nine groups/135 lines to seven groups/124 lines. The largest vertical
scenario remains CC 11/cognitive 25; it was not split to chase heuristic scores.
The bounded diagnostic branch increases its local complexity and is retained for
resource safety, not treated as a regression to hide.

The Qt fixture adds useful typed helper arguments while retaining optional-preview
semantics. Its stale-subscription case now actually acknowledges the fresh
subscription before delivering retired records, verifying that the fresh ID stays
owned. Three new-test annotation findings were resolved, with no introduced QML
finding identities. The two long-scenario observations remain intentional review
signals. Overall QML semantic evidence is still **partial**: sixteen unresolved
import/type references and 72 skipped evaluations in the narrow test/context
scope are not semantic passes or production defects. Real Qt/lint do not erase
those lens limitations. No thresholds, suppressions or baseline exclusions changed.

Post-refactor checks: formatting, strict all-target/all-feature Clippy, embedded
fake shell `bash -n`, three serial repeats of both private process tests/all eight
phases, full QML lint and actual Qt **435 passed / zero failed / one existing
renderer skip**. The embedded shell string is not shell-analyzed by either lens;
syntax checking and private execution are its bounded evidence.

Updated debug test ELF SHA256:
`fe8101ef1a06393d5c43e58480d2f6a04238c2b9b929d0c26059ed2a04ceb91b`.
Rust test source SHA256:
`007fc0d1cf8404be6209d9e2ab8e65626cf05a721ca02f8f22ecddd9a7404d0e`.
QML test source SHA256:
`88d7ba78666f4ff6837eef63b24e55ba09f4bc73966c1b5a7788a80e171bcd8e`.
Compiler, Qt runner and frozen framework identities are unchanged. All original
unqualified startup/live-effect/load/release/rollout scope remains open. This
quality checkpoint requires coordinator semantic review; it is not approval.
