# Startup/readiness coordinator review — 2026-10-26

**Disposition: reviewed design, committed for follow-up; strategy decision and
runtime qualification remain open. Bridge stays default.**

Reviewed [startup/readiness proposal](../contracts/socket-startup-design.md),
originally delivered as Shelllist worker commit
`67c46dd4177cd669d2f58b9124e33e01060e2b58`. The coordinator reviewed the source at
its frozen checkpoint (identities in the proposal), integrated the document and
made the corrections below. This is not acceptance of a new startup behavior,
a claim of runtime safety, or authorization to deploy/enable producer policy.
Parallel code-worker changes were not incorporated or qualified by this review.

## Findings and disposition

| Finding | Source evidence / review disposition |
| --- | --- |
| Connection readiness is not compatibility or action eligibility | Confirmed in `qml/Shelllist/Io/process/JsonlDaemonClient.qml::transportStarted`: `ready = true` precedes subscription setup/queue flush. `DaemonSessions.qml::isReady` returns client readiness, and `DaemonBackend.qml::call` has no universal producer compatibility check. Existing request validation/domain policies remain real but do not establish that gate. Added explicit transport, compatibility, consumer-baseline and action-eligibility requirements. No incompatible effect was executed to demonstrate this source-visible gap. |
| Generation/producer identity needs an explicit binding | Added rejection of old-generation and separate-probe evidence. Framework `src/dbus.rs::JsonDbusClient` constructs proxies from the endpoint bus name, while `src/owner.rs::wait_for_name_replacement` observes replacement asynchronously. A future compatibility gate must prove dispatch binding to the verified unique owner, not merely rely on receiving that signal before another call. This review does not claim to have reproduced a bridge replacement race. |
| A blanket startup gate can block cleanup or healthy peers | Added explicit current-owner cancel/release/shutdown handling, per-consumer baseline isolation, and valid loading/unavailable observations. Readiness is never authority to replay effects, inherit a retired owner's lease or bypass native admission. |
| Startup delay can preserve stale intent or excessive payloads | Required deadline/generation fencing of callbacks and unsent requests, with explicit byte/count/age limits if effects are queued. The existing startup limit is 256 requests; native write reservations do not by themselves establish a byte bound on that earlier queue. The proposed 30s budget remains unmeasured and undecided. |
| Universal session-target ordering was too prescriptive | Removed the blanket `After=<session target>` recommendation. Current Shelllist and several producer definitions use target ordering, while Clip uses `graphical-session-pre.target` plus engine/watcher ordering. Require the complete rendered graph, default dependencies, enablement and environment-ready boundary. No actual installed ordering cycle is claimed or tested here. |
| Metadata coverage wording exceeded completed migration scope | Restricted the rejection statement to reads/streams whose contracts require that metadata. The stream matrix still lists open BT/NM lifecycle rows; the design cannot close them by assertion. |
| Packaged units do not prove socket readiness | Confirmed all five producers start their listener after D-Bus export/name acquisition. App is `Type=simple`; the others are `Type=dbus`. Bind failure propagates out of each daemon's run path. A completed service start/name claim does not establish socket or domain readiness. |
| PATH/package closure is not resident service identity | Confirmed UI-only NixOS/HM module scope and separately owned producer units. Retained the requirement to inspect effective unit/activation paths, overrides and resident identities for a matched release. |
| Clipboard package-smoke fixture is stale | Confirmed `clip-daemon/scripts/package-smoke.py::call` uses `BUS + "1"`, while the current interface is `org.laufan.ClipDaemon2`. No script was run or fixed in this documentation change. Its private activation environment still needs review before reuse; existing engine negotiation v2 is a different version axis from the D-Bus interface. |

Framework source paths in this table are relative to
`daemon-framework/crates/shelllist-daemon-tokio/`; other unprefixed paths are
relative to Shelllist. Producer startup anchors are each producer's
`src/daemon.rs` and `src/daemon/socket.rs`. Runtime-path/lock claims were checked
against framework `src/socket/path.rs`; no filesystem repair or listener was run.

## Recommendation retained, decisions not made

Independently configured eager services are a reasonable **first qualification
candidate**, because they reuse shipped supervision without an inherited-FD
rewrite. This is not evidence that eager startup is faster/cheaper, suitable for
every daemon, or independently authorized to start capture/notification policy.
Application laziness and non-systemd support remain explicit alternatives.

Before implementation, decide:

1. Strategy/per-daemon exceptions, especially applications.
2. Effective unit/activation composition owner, supported session model and
   environment-ready boundary (including the differing BT/NM lifetimes).
3. Producer-owned compatibility facts, shared dispatch gates and bounded startup
   behavior, including interaction of the proposed 30s budget with current timers.
4. Matching package/runtime tuple and private acceptance scope.

Default changes and installed/live-session activation require separate approval
after the implementation and remaining migration gates pass. A documentation
commit is not that approval. Socket activation is not selected; its unimplemented
FD/path/backlog/dual-activation work remains conditional.

## Checks and evidence limits

Coordinator checks performed for this documentation-only integration:

- Reran the original worker's read-only source audit on its unchanged frozen
  family: seven source identities, five service/activation/socket definitions,
  path/deadline/version observations, original design links and clean scope.
- Reviewed the implementation source anchors above, module composition, stream
  inventory and producer capture/rollback documentation.
- Checked local Markdown links/fence balance in the final proposal and this
  review record; checked the reviewed readiness requirements remain explicit.
- `git diff --check` and `git diff --cached --check`; verified the integration
  contains only the proposal, this evidence record and its `tests/README.md` link.

Review logs are retained in the local orchestration task
`tasks/07-startup-design/coordinator-review/` under run `20261026T142325Z`.
The source audit reads files and Git metadata; it is not a service-manager,
compiler, Qt or daemon-runtime test. It does not execute the proposed gate.

**Not run:** producer binaries, buses, service activation/restarts, systemd job
transactions, Qt/native tests, package builds, upgrade/rollback, hardware/clipboard
or load/performance tests. No Lens code-quality pass applies to Markdown-only
changes. No existing quality, acceptance or deployment gate is waived.

Implementation acceptance is the proposal's section 8 matrix, including zero-effect
pre-gate counters, reentrant calls, stale probes, owner replacement, independently
delayed phases, safe cleanup, private real process death and matched runtime
identities. That matrix remains pending; source review is not its substitute.
