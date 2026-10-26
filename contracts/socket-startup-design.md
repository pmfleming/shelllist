# Socket cold-start, packaging and safe rollback — decision proposal

**2026-10-26 · coordinator-reviewed design / needs-decision · not rollout-approved.**
See the [review findings and evidence limits](../tests/startup-readiness-review.md).
Review and committing this document do not select or implement a startup strategy.
This is an audit of the frozen migration checkpoint, not a startup-policy change.
The bridge remains default. D-Bus and all five `<daemon> client` bridges remain
supported. Nothing here authorizes installation, activation, service restarts,
new capture/power/notification policy, or a transport-default switch.

## 1. Recommendation and decision boundary

**Recommend independently configured eager producer services for the first
packaged socket qualification**, conditional on coordinator/user approval. Use
existing producer-owned services, at the selected graphical session boundary,
with bounded per-daemon connection/compatibility readiness. Do not make the UI
own daemon policy, stop producers when the UI closes, or block the whole shell on
one unavailable producer. This is a proposed qualification strategy, not a choice
already applied to the runtime or a claim that every producer should always run.

Reasons: bar and clipboard own background policy independent of visible panels;
BT/NM are already eager frontend consumers for status/private prompts. All five
packages already ship restartable services. Eager startup needs no listening-FD
handoff rewrite and avoids introducing an activation helper with authority to
start arbitrary services. It does **not** eliminate readiness races. The cost is
starting applications earlier than its currently lazy surface requires, and
potentially starting other independently configured policies earlier. No measured
cold-start/resource comparison in this checkpoint establishes that cost as small.

Alternatives remain legitimate (section 4). If preserving application on-demand
startup or non-systemd session support is required, approve a separate explicit
activation design instead of quietly applying the eager recommendation.

Decisions required before implementation:

1. Choose eager qualification, explicit activation, or fund inherited-listener
   support; choose per-daemon exceptions (especially applications) explicitly.
2. Name the deployment composition owner: NixOS **or** Home Manager/manual unit
   integration for each service, selected session target and environment source.
   Shelllist's existing UI-only modules must not silently enable producer policy.
3. Approve the readiness/compatibility gate and degraded-per-daemon behavior below,
   including a finite startup deadline; decide supported non-systemd startup.
4. Name the matching release/rollback package tuple and owners of shared Io/Core,
   framework and producer changes. Approve implementation/isolated tests separately.
5. After those tests and remaining migration gates pass, obtain **another** decision
   for each default change and for any installed/live-session acceptance. Approval
   of this design is neither default selection nor deployment authorization.

## 2. Frozen source evidence

Paths prefixed by a repository name below are relative to the sibling family.
These are source observations, not newly executed package/native acceptance.

| Repository | Audited HEAD |
| --- | --- |
| shelllist | `d7a3a5e530a0fd350075f1ca85e3f83539dc6089` |
| daemon-framework | `563e7f95e0b976e1e2eb483bc4e983623f0e8fc5` |
| bt-daemon | `3e0ecb4f81aeada42cd3623dedb7fa4d3c46995f` |
| nm-daemon | `0396f009eca7f28219e8da23ba69e9eac720a7f9` |
| app-daemon | `bb013f1659e2e4b2689fc19d4c331affd5624662` |
| bar-daemon | `cca60419d933c995d61d297be19847496c05de68` |
| clip-daemon | `80ffa46de5346f4599a4af79ce0b7caa488c142e` |

### 2.1 Services and packaged activation

Each producer's `packaging/systemd/<daemon>.service` and
`packaging/dbus/org.laufan.*Daemon.service` were inspected. Each D-Bus file has
`Exec=@out@/bin/<daemon> daemon` and `SystemdService=<daemon>.service`; each flake's
`postInstall` installs those files and substitutes the output path. These support
bus activation **when the deployment exposes the activation files/units**; mere
presence in Shelllist's executable PATH does not register/enable them.

| Producer / bus name | Packaged service type, install target | Existing ordering/lifetime details |
| --- | --- | --- |
| BT / `org.laufan.BluetoothDaemon` | `dbus`, `default.target` | `After=graphical-session.target bluetooth.target`; state directory 0700; no `PartOf` in this unit |
| NM / `org.laufan.NmDaemon` | `dbus`, `default.target` | `After=graphical-session.target`; no `PartOf` in this unit |
| App / `org.laufan.AppDaemon` | `simple`, `graphical-session.target` | `After` and `PartOf=graphical-session.target`; no `BusName` readiness |
| Bar / `org.laufan.BarDaemon` | `dbus`, `graphical-session.target` | `After=graphical-session.target dbus.service pipewire.service wireplumber.service`; `PartOf=graphical-session.target`; conflicts with and orders before `swaync.service`; native notification backend |
| Clip / `org.laufan.ClipDaemon` | `dbus`, `graphical-session.target` | `After=graphical-session-pre.target ringboard-server.service ringboard-wayland.service`; `PartOf=graphical-session.target`; **Wants**, not Requires, Ringboard; conflicts with legacy watcher; private state/cache, umask 0077, 30s stop timeout |

All five have `Restart=on-failure` and approximately two-second restart delay.
`After` is ordering only, not a pull-in, readiness proof or a cross-manager system
service dependency. For example BT's user-unit `bluetooth.target` ordering is not
proof that system BlueZ is ready. A packaged `WantedBy` is not an enabled link.

Additional integration audited:

- `bar-daemon/packaging/session-service.nix` is the NixOS/HM shared session unit:
  configurable target, optional display-controller conflict/order and policy
  environment. Its modules own optional notify-ready hypridle and privileged
  helper integration; those are not socket-activation dependencies to invent in
  Shelllist. The package also ships `org.freedesktop.Notifications.service` pointing
  to the **same** bar service. Keep that singleton/conflict behavior on both paths.
- `clip-daemon/packaging/systemd/ringboard-server.service` is `Type=notify`, runs
  `clip-daemon configure-engine` before its pinned Ringboard executable, and is
  session-bound. The facade deliberately survives an engine restart used by
  retention changes: do **not** add `Requires`/`PartOf=ringboard-server.service`.
  See producer `docs/installation.md` and `docs/adr-0003-daemon-wayland-capture.md`.
- `shelllist/nix/{nixos,home-manager}.nix` supervise only `shelllist run`, after and
  part of their configured target. Neither registers/starts the five producers.
  `shelllist/flake.nix` puts matching daemon/client executables and `pkgs.quickshell`
  in the UI wrapper PATH; it does not ensure the independently installed resident
  service has the same executable. App's NixOS module only grants optional RAPL
  access; it does not configure its session service. Independent ownership is
  also recorded in historical `71e1b3e:docs/daemon-packaging.md` (ignored reference).

### 2.2 Actual producer readiness

All five `src/daemon/socket.rs::listen` functions require `XDG_RUNTIME_DIR`, bind
through framework `JsonlListener::bind`, and serve the **same admitted in-process
object** exported on D-Bus. No producer accepts systemd listening FDs here. All five
`src/daemon.rs` start the socket task **after** exporting/claiming the bus service:

- BT: bus export, OBEX activation, background snapshot tasks, then socket task.
  Native loading snapshots are valid; populated hardware state is not required.
- NM: NetworkManager runtime creation, bus export, SecretAgent export/watch,
  then socket task. A bus-name acquisition can precede SecretAgent/socket readiness.
- App: service creation and bus export, then socket task. `Type=simple` signals
  process start, not even bus-name readiness.
- Bar: native notification initialization, bus export (including notification
  name where selected), monitor tasks, then socket task.
- Clip: owner monitoring/object export, bus-name claim, settings/retention/capture
  initialization, then socket task. A claimed name does not assert capture privacy
  was verified; desired/effective status remains authoritative.

A bind/listener task error is propagated as daemon failure, not an optional loss
of only socket support. Thus bad runtime configuration can also break retained
D-Bus service availability. Conversely a `Type=dbus` start job can report success
before socket binding succeeds. Unit ordering alone cannot close this gap.

### 2.3 Frontend readiness and compatibility limits

Sources: `shelllist/qml/Shelllist/Io/process/{JsonlDaemonClient,
JsonlSocketTransport}.qml`, `DaemonSessions.qml`, `DaemonBackend.qml`,
`JsonlRouting.js`, and `Core/ApiEnvelope.qml`.

- Exact `SHELLLIST_{BT,NM,APP,BAR,CLIP}_SOCKET=1` flags select independently.
  Otherwise the process bridge is used. There is no automatic fallback.
- Socket path is the environment string plus `/<daemon>.sock`; an absent runtime
  gives an empty path and is rejected. QML checks an absolute path, not the
  producer's canonical-directory/ownership rules. No `/tmp` or HOME fallback exists.
- One session per daemon multiplexes consumers. `ready` becomes true at native
  socket connection (bridge: process start), before subscription acknowledgement,
  envelope/metadata validation or a domain baseline. Ready callbacks can send
  calls, and the startup queue is flushed; **there is no universal pre-effect
  compatibility handshake**. Startup queue limit is 256 requests.
- Connection deadline is 5s; socket acknowledgement/shutdown deadline is 35s.
  Retry is exponential from 1.5s to 30s (delay bounded, not total attempts).
  Failure retires the native object/queued generation, advances route generation,
  notifies consumers and restores subscriptions on a later connection. It never
  migrates an uncertain call into the bridge or a new socket generation.
- Envelope protocol/version, routed responses and producer-owned native metadata
  are validated at their existing boundaries. Where a migrated read/stream requires
  ordering metadata, old unwatermarked data is not a valid fallback on **either**
  transport. This is not a claim that all BT/NM lifecycle rows already have such
  metadata or validation; see
  [recovery](unix-jsonl-stream-recovery.md) and
  [stream matrix](unix-jsonl-stream-matrix.md). Rejection on receipt does not prove
  an effect could not already have reached an incompatible producer.

## 3. Runtime-path and connection ownership contract

Sources: `daemon-framework/crates/shelllist-daemon-tokio/src/socket/path.rs`
and `daemon-framework/crates/shelllist-daemon-tokio/src/socket.rs`.

- The runtime must already exist, be absolute, canonical (no aliased/symlink path),
  owned by effective UID and mode exactly 0700. Do not chmod/create a shared host
  runtime directory as a repair. Deployment must give frontend and producer the
  same validated path and intended session environment.
- `.<daemon>.sock.lock`: `NOFOLLOW`, `CLOEXEC`, ordinary UID-owned mode-0600
  single-link file with exclusive nonblocking flock. **Never unlink the lock**:
  replacing its inode could admit a second binder. Lock files may remain after
  clean stop/crash; a leftover file is not evidence that the lock is held.
- A pre-existing pathname is replaceable only if it is a same-UID socket,
  a bounded 200ms connect reports connection refused, and inode identity has not
  changed. Live/unresponsive sockets, files, symlinks and foreign owners fail closed.
  New sockets are mode 0700; drop unlinks only its own matching socket inode.
  After SIGKILL the OS releases flock but may leave a stale socket; restart must
  use this existing stale check, not `rm`/`ExecStartPre` cleanup.
- Kernel peer UID is checked before reading. Each accepted connection gets an
  entropy-backed `unix:...` owner; no JSON, PID or previous connection can nominate
  ownership. Unavailable entropy rejects ingress. Route generations are frontend
  fences, not daemon epochs or reconnect authority.
- Disconnect cancels/releases only owned resources. Accepted work retains its
  admission permit while completing/reconciling even after reply timeout;
  late registration repeats owner cleanup. Cancellation is not rollback of a
  launched application, published selection, injected input or hardware effect.
- Graceful socket `shutdown` drains that **connection**, not the resident daemon.
  Stopping the shell is not authority to stop background policy. Graceful producer
  shutdown closes ingress/owners and follows existing domain cleanup. SIGKILL
  cannot run cleanup or preserve in-memory outcomes; effects in other processes
  may already have happened. Recovery reads valid current state/owned status only;
  a retired owner cannot regain private outcomes merely by knowing an operation ID.

No two concurrent graphical sessions for the same UID are isolated by these
UID-wide names. Decide a supported single-session policy (current names imply
one resident per UID) or a separately designed session namespace before claiming
multi-session support. Never redirect an effect to a discovered other compositor.

## 4. Strategy comparison

| Strategy | Project fit / costs | Required work and failure model |
| --- | --- | --- |
| Eager producer services (recommended candidate) | Reuses shipped supervision; appropriate for independent bar/clipboard policy and eager BT/NM consumers; starts app earlier and may increase startup work | Explicit deployment enablement/environment composition; per-daemon readiness/compatibility, deadlines and package matching still required. Missing service stays unavailable; no UI-spawned duplicate and no replay/fallback. |
| Explicit activation before socket connect | Preserves lazy app startup and resembles retained bridge cold-start; D-Bus remains a real dependency of every current producer | Shared allowlisted activation boundary, bounded activation plus socket/protocol readiness, cancellation/coalescing for many consumers, and clear non-systemd behavior. Prefer existing bus activation (`StartServiceByName` or an audited side-effect-free producer startup read), not a domain mutation or arbitrary `systemctl` QML command. A completed activation job/bus-name claim is not socket readiness. No such helper is currently implemented. |
| Socket activation | Can queue connections before process start; demand-driven ingress without a persistent bridge | New `.socket` units **and** framework/producer FD adoption, manager-owned path lifecycle, concurrent D-Bus activation and failure-queue qualification. Current binder would conflict with a manager-owned socket. Does not avoid producer D-Bus/backend initialization. Most invasive for an initial default; no measured benefit justifies choosing it now. |

If socket activation is selected later: use `Accept=no`, one daemon service and
one listening FD per endpoint, never a per-connection daemon (`Accept=yes`). The
framework must validate `LISTEN_PID`, FD count/name, listening AF_UNIX stream type,
expected address/modes/UID, and acquire/convert the FD safely with explicit error
handling. A new inherited-listener API must distinguish **manager-owned** pathname
lifetime from the self-bound lock/inode-unlink path. It must not call the existing
binder on that path or unlink it on daemon exit. Producer adapters still share the
same service/coordinators. Mixed D-Bus/socket starts must converge on one service;
FD discovery when the service is bus-started first needs a tested dependency/job
model, not two independent activation stacks. Old packages lacking FD support must
not be started with new `.socket` units; rollback must stop that listener first.

**Socket activation can retain a listening socket and unaccepted backlog, not
accepted connections or their owners across crashes.** Accepted file descriptors,
subscriptions, admission bookkeeping and non-durable outcomes die with the
process. `FileDescriptorStore`/owner resurrection is not proposed. Backlog clients
may connect and buffer bytes before initialization, so connection success is even
less meaningful as readiness. Buffered requests are not a durable journal: timeout,
client retirement, queue overflow and service restart must never be turned into
automatic retries. Test delayed/abandoned backlog peers and prevent effects before
a fresh compatibility gate. A new connection always has a new owner.

## 5. Proposed dependency / service-order graph (not installed)

Legend: `-->` initialization/order; `~>` wants/start request; `[ ]` independent
failure boundary. There are no required producer-to-producer startup edges here.

```text
selected graphical session / environment import
  (private canonical runtime; intended Wayland/compositor identity; session bus)
  --> selected session target active
       ~> [BT service]  --> bus export / initialization --> socket bind
       ~> [NM service]  --> runtime / bus / SecretAgent --> socket bind
       ~> [App service] --> service / bus export        --> socket bind
       ~> [Bar service] --> notification / bus / tasks  --> socket bind
       ~> [Clip service] --> bus / policy initialization --> socket bind
              ~> [Ringboard notify-ready server]
                   configure-engine --> engine readiness
       ~> [Shelllist UI service]
              --> per-daemon connect --> compatibility/subscription gate
                  --> valid baseline/loading/unavailable state
                  --> domain-authorized new requests

external D-Bus caller / retained bridge
  ~> registered bus activation --> SAME producer service/coordinators
system backends, audio, compositor, helpers
  --> producer domain capability/health (not UI-owned activation)
```

Clip's existing `Wants` plus `After` orders its engine start when available; engine
absence is degraded health, not permission to lie about capture or stop the facade.
Bar's notification/display conflicts and managed idle readiness remain in its
producer module; do not create a second notification collector or relax lock,
active-session, polkit or hardware guards. Preserve old clipboard watcher exclusion.

Implementation constraints for the chosen composition:

- Register activation files and matching units/executables explicitly; verify
  effective definitions/overrides, not only derivation closure membership. Choose
  one session-unit owner, and establish compositor environment **before** starting
  session-sensitive producers. Audit BT/NM's `default.target` policy against this
  requirement rather than silently changing it to a session target.
- Derive ordering from the selected session manager's documented environment-ready
  boundary and the **complete rendered job graph**, including target default
  dependencies, enablement links and drop-ins. The diagram is conceptual, not a
  blanket `After=<session target>` recipe: combining target pull-in with ordering
  can create cycles, and Clip currently orders after the pre-target instead.
  This audit establishes no live-manager cycle or universally safe target choice.
  Do not fix ordering by disabling default dependencies indiscriminately. Optional
  UI `Wants`/`After` producer edges, if explicitly approved at deployment composition,
  are not readiness gates. Do not `Requires`/`BindsTo` all producers from the UI or
  stop policy daemons when a panel or UI consumer disconnects.
- Propose a **30s total per-daemon startup window for qualification**, covering
  activation if selected, connect, compatibility and subscription readiness.
  Retain bounded retries after unavailability without replay. This is a proposed
  budget, not a measured SLA or an instruction to change the current 5s/35s
  transport deadlines; measure slow fake initialization and decide before coding.
  Keep service-manager failure/start-limit state authoritative: reconnect backoff
  must not reset limits or repeatedly spawn a failed producer behind the manager.
- Add shared connection-versus-compatibility readiness, using producer-owned
  contracts/capabilities or audited read-only startup responses; no generic hello
  is currently available across all five producers. Rust owns compatibility facts;
  shared Io/Core owns gating/routing, not domain schema copies in panels. Do not
  flush queued effects or dispatch them from a raw `ready` callback before the gate.
  Validate exact envelopes, required clocks/route support and subscription baseline
  for the selected domain. Loading/unavailable **with valid metadata** is a valid
  health observation, never a fabricated successful effect or healthy hardware.
- Startup failure isolates a daemon's consumers. Keep private drafts and existing
  accepted/unknown-work guards; preserve Enter/Tab save, Escape discard and explicit
  retry. Reconnection restores observations, not confirmations, leases, secret
  prompt authority or clipboard hidden-session acknowledgement. A secret observer
  must not claim it can answer an old prompt until native authorization says so.

### 5.1 Readiness contract required before implementation

Use distinct facts rather than upgrading the meaning of the existing `ready`
signal implicitly. Exact API/DTO names remain an implementation decision:

1. **Transport connected:** the native socket connected or bridge process started.
   This does not attest the resident producer, subscriptions, hardware or authority.
2. **Compatible endpoint:** a successful, structurally validated, producer-owned
   read-only response establishes the required protocol/capability tuple for this
   live connection and frontend generation. Do not reuse a result from a previous
   generation, another daemon/transport or a standalone probe connection. For a
   bridge, qualify how it binds the facts to the resident D-Bus unique owner and
   retires them on owner replacement; a new client executable is insufficient.
   An asynchronous name-owner watcher alone is not an atomic dispatch fence if
   calls can still target a replaceable well-known name. Bind dispatch to the
   verified unique owner, or prove an equivalent native fencing mechanism.
   Any producer-lifetime discontinuity invalidates this fact before further effects.
3. **Consumer observation ready:** the particular consumer has its required valid
   baseline and acknowledged subscription, with the ordering semantics prescribed
   by its domain. Do not block a healthy consumer on another consumer's optional
   stream, or require populated hardware instead of a valid loading/unavailable
   observation. Domain gaps/renewal invalidate the affected observation, not by
   themselves every consumer's compatibility or accepted-work authority.
4. **Action eligible:** the selected action additionally satisfies current native
   authorization, capability and lifecycle rules. A compatible connection, a valid
   baseline or a loading/unavailable state is never permission to bypass these
   rules. UI drafts and editing transactions remain local until explicit save.

The shared dispatch boundary must enforce these gates for startup queues, direct
calls and reentrant `ready` callbacks, not only disable a panel control. Required
method/capability facts come from producer contracts/generated bindings; panel-local
method-name heuristics are not a second authorization system. Specify the minimal
pre-gate allowlist: audited read-only compatibility/observation calls, and only the
control/subscription operations needed safely for initialization. Starting a paste,
edit session, wipe challenge, launch, scan or capture is not a readiness probe.
Activating a producer may itself start independently configured background policy;
a read-only probe is not authorization to enable that policy.

Keep bounded cancellation, release and shutdown possible for resources already
owned by the **current** connection, without waiting on a failed new baseline or
reopening a closed admission gate. Cancellation remains native-owner checked and
is neither proof of a terminal outcome nor rollback. Never send retired-owner
operation IDs or private authority through a replacement connection.

A startup deadline must retire pending initialization and fence late callbacks.
Do not repeatedly reset the total budget at each phase, keep an expired effect
queued for a later connection, or transmit it merely because a late compatibility
reply arrives. Preserve the distinction between a definitely unsent request and
an uncertain dispatched effect. Later retries may restore observations; a new
user effect needs fresh eligibility and the existing explicit retry/confirmation
rules. If unsent effects may wait for readiness instead of being rejected as not
ready, specify byte/count/age bounds and clear sensitive payloads on retirement;
the current 256-request startup cap is a count bound, not a byte budget. Do not
extend a compatibility wait by retaining an unbounded payload queue. The proposed
30s window and its interaction with 5s/35s transport timers still require a decision
and private delayed-start tests.

These are frontend eligibility requirements, not an implemented server handshake
or a substitute for Rust admission/authorization. External D-Bus clients do not
inherit a QML guard; their compatibility and native policy remain separately tested.

## 6. Supported runtime and mismatch behavior

The recorded native adapter qualification is **Quickshell 0.3.0 on x86_64-linux**,
using `Quickshell.Io.Socket` (`path`, `connected`, connection/error signals,
`write`) and `SplitParser`. See
[clipboard evidence](../tests/clipboard-socket-qualification.md) and the recovery
contract's BT/NM/app/bar evidence. This audit ran no Quickshell binary. It establishes
neither an earlier minimum nor blanket compatibility with later versions. The
flake selects `pkgs.quickshell` from its locked nixpkgs; there is no explicit runtime
version guard in this adapter. Qualify and record the **actual** wrapper-resolved
version/store path/hash before a release; unsupported Socket APIs must fail without
starting effects. Keep the bridge available as a deliberately selected, matching
configuration, not an automatic recovery from a partially dispatched socket call.

The shared native envelope contract at this checkpoint is version **2**
(`daemon-framework/crates/shelllist-daemon-core/src/contract.rs::CONTRACT_VERSION`).
Version equality alone is insufficient: required native clocks/routes changed
within the migration. A closure manifest and producer-owned capability/baseline
validation must establish the accepted combination. Do not privately emulate
missing schemas/watermarks in QML or downgrade validation to make startup green.

| Mismatch/failure | Safe behavior |
| --- | --- |
| New frontend, older/malformed producer | Current readers reject incompatible/missing metadata. Proposed pre-effect gate must keep calls unavailable before any effect; show/recover domain unavailability using existing UI composition, not fallback dispatch. |
| Old frontend, new producer | Only support a separately tested compatibility tuple, including retained bridge/external D-Bus. New packages alone do not prove old consumers work. |
| Wrapper client package differs from resident D-Bus executable | Report matching-build failure; inspect effective unit/activation path. A new client in PATH does not upgrade the bus owner. |
| Missing/aliased/unsafe runtime or live foreign pathname | Fail closed; no alternate directory, unlink/chmod repair, producer fork or alternate compositor. Existing listener failure also fails D-Bus startup. |
| Start/name claim succeeds, socket later fails | Per-daemon deadline/health fails; retain other sessions. No claim of successful activation readiness and no effect replay. |
| Crash/disconnect around acceptance/terminal receipt | Unknown unless authoritative evidence remains accessible to the same valid owner. Missing status/expired cache/new owner is not success. Reconnect reads current state only. |

Audit caveat: `clip-daemon/scripts/package-smoke.py::call` constructs `BUS + "1"`,
while current `src/daemon.rs` exports `org.laufan.ClipDaemon2`. That script's earlier
installed-activation result is historical, **not** a fresh v2 acceptance gate. Its
private bus construction also needs an explicit no-host-activation review before
reuse. Request a producer-owned fixture update; do not run it unchanged or treat
its documentation as current binary evidence.

## 7. Upgrade and rollback cases

These are procedures to implement/test in private fixtures, not commands to run
against the installed desktop.

1. **Transport-only opt-in/rollback, matching binaries.** Quiesce new UI effects;
   preserve/label accepted or uncertain work, drain where feasible, retire the old
   connection and establish a fresh owner/baseline on the deliberately selected
   transport. Unset only the selected daemon's exact socket flag for a future
   frontend generation. No pending call queue, operation ID, secret, paste session,
   confirmation, edit lease or hidden-ack authority is transferred. Do not invoke
   a mutation as a readiness probe or automatically retry a save. Current flags
   are process-environment selection, not a safe live per-request toggle. Restarting
   the UI may lose in-memory drafts: obtain an explicit user decision, do not
   persist sensitive drafts or call that loss seamless rollback.
2. **Matching package upgrade.** Capture the frontend, framework, all affected
   producers, helpers/engine and Quickshell identities from one sibling-source
   snapshot. Quiesce effects and record uncertainty before replacement. Replace
   effective unit and activation paths together; a profile switch alone does not
   replace a running bus owner or explicit old store-path unit links. Start the
   selected producers, pass readiness, then attach the matching frontend. Every
   lost connection has new owner/route/producer state fences, not resumed private
   authority. Keep external D-Bus registration and bridges available.
3. **Partial upgrade or failed readiness.** Keep affected domains unavailable and
   unaffected peers usable. Select a verified full compatible tuple or repair
   configuration deliberately. Do not bounce between versions/transports or
   repeat an uncertain launch/connect/capture/publication/paste to test recovery.
4. **Package rollback.** Retain a known-good complete closure and declarative
   configuration. Stop/quiesce the replaced stack before selecting old paths;
   account for in-flight work whose effect escaped the process. Revalidate state
   formats/capabilities and privacy intent with synthetic data; do not assume
   rolling back transport reverses settings, retention eviction or notification
   history. Never restore a backup with active writers or delete real caches.
5. **Clipboard engine/collector rollback.** Transport rollback does **not** require
   reverting the two-service capture design. If that package architecture is also
   rolled back, follow producer `docs/installation.md`: preserve paused/private
   intent; stop new collector and engine before restoring an old daemon/server/
   watcher closure; verify the old privacy startup condition; never overlap
   collectors. Old watcher masks/links need deliberate review. Patched Ringboard
   admission remains mandatory; no stock-engine fallback or automatic retention
   lowering/data restoration. Existing engine-only synthetic rollback is not full
   frontend/daemon/collector rollback evidence.
6. **Session stop/crash.** Use producer-owned session lifetimes and bounded shutdown;
   verify BT/NM's intentionally different packaged lifetime before promising they
   stop on logout. UI quit must not stop independent policy. Forced termination
   loses receipts; startup does not reconstruct missed historical edges or replay
   unknown work. For a future activated socket, stop the listening unit as well
   during planned shutdown/old-package rollback to prevent unwanted reactivation.

## 8. Isolated acceptance plan and implementation handoff

**Not run by this design-only checkpoint.** Each row requires matching source and
binary evidence, bounded deadlines and retained metadata-only fixture logs under
`tests/` when implemented. Tests must use private HOME/config/data/cache/state/
runtime, fake producer backends and a private D-Bus configuration with no host
service activation directories/helpers; frontend host bus/Wayland endpoints remain
unavailable. A disposable user-manager VM may test unit semantics with fake service
entrypoints only. Neither `dbus-run-session` alone nor an actual daemon constructor
is proof of safety. Inspect constructors and existing harnesses before reuse.

| Gate / owner | Required private evidence |
| --- | --- |
| Package composition / integration owner | Sibling-source preflight, matching package build, rendered unit/activation output paths, no placeholders, correct registration/enablement, no duplicate unit owners; inspect complete user-manager job/order graph, including configurable target and notification/display conflicts. No cycles or reliance on `After` to start services. |
| Fresh cold start / shared frontend + producers | All five absent initially; chosen strategy starts registered fake services without manual pre-start. Many consumers coalesce to one resident/one frontend socket per daemon. Delay bus claim, socket bind and baseline independently; ensure no effect before compatibility and finite per-daemon unavailability without blocking healthy peers. |
| Runtime paths / framework owner | Canonical 0700 success; absent/noncanonical/symlink/0755 runtime, foreign/file/symlink socket, unsafe lock, held lock, live/unresponsive socket fail; stale same-UID socket after real child SIGKILL recovers. Never unlink lock or another inode. UID rejection requires an isolated multi-UID fixture, not changing host files. |
| Compatibility / Io/Core + producers | Old envelope, missing required route/native clock, same-version old schema, wrong wrapper/resident, unsupported Quickshell APIs, malformed baseline: effect counter stays zero before gate. Exercise prequeued calls and reentrant ready callbacks; a delayed old-generation probe or replaced D-Bus owner cannot unlock effects. Unavailable domains have no bridge/alternate-path dispatch; valid loading/unavailable observations do not require healthy hardware. Independent consumer renewal does not revoke healthy peers. Retained bridge and external D-Bus pass a separate compatible tuple. |
| Failure/ownership / producer owners | Real fake-backend child killed before ack, after acceptance, during terminal delivery and after effect-before-receipt. Restart has fresh owner/epoch; foreign old-status access rejected, missing outcome unknown, no effect replay. Separately, with the process alive, peer loss retains accepted admission through cleanup/reconciliation and leaves a surviving owner unaffected. No claim that admission survives process death. |
| Shutdown / integration + domain owners | UI/consumer close drains/releases without stopping policy; slow/failed domain cleanup bounded; current-owner cancel/release/shutdown still work during failed readiness without reopening effect admission. Startup deadline fences late callbacks/queued effects; logout/forced stop rejects new admission; engine restart does not stop Clip facade; no old watcher reactivation and no duplicate notification owner. |
| Upgrade/rollback / integration + producer owners | Both directions for matching tuples; deliberately mixed paths fail safely; transport-only rollback preserves uncertainty and does not transfer leases/prompts/hidden authority. Synthetic persisted state/paused-private intent preserved; no cache removal/real data or effect. Future FD activation adds backlog, bus-first/socket-first, stale FD and listener-stop rollback rows. |
| Native frontend / shared owner | Real packaged Quickshell 0.3.0 production shared session with safe private producers, two consumers, delayed readiness, generation retirement, reconnect, peer release and baseline races; actual Qt regressions for drafts/accepted guards, Enter/Tab save, Escape discard and explicit retry. |
| Serial release measurements / qualification owner | Later, under the shared lock and no concurrent workers: identify exact sources/closure/ELF hashes, warm/cold definition, payloads/sample counts, startup phases, p50/p99 and process-tree RSS/PSS/private memory. Compare matched bridge/socket only; report daemon+client+engine scope. Passing builds or smoke tests are not measurements. |

Build/test reproduction policy: use this family's
`../daemon-framework/tools/local-build` (see its `docs/local-build.md`), Git-add new
tracked inputs (`git add -N` before snapshots), and run every heavy/native/Nix check
through the orchestration `check.sh` with an outer deadline. Do not bypass preflight,
reuse original-checkout targets, update deployment locks or install packages.
Existing [test instructions](../tests/README.md) and private native probes are
starting points, not substitutes for the new cold-start/job-graph tests. Final
source hashes, resolved package/Quickshell/producer hashes and exact commands/logs
must accompany the eventual runtime evidence.

Implementation tickets after a decision (no code changes in this checkpoint):

- **Integration owner:** independently compose producer registration/enablement,
  target/environment and compatible closures; unit-graph/fresh-session fixture.
  Preserve UI-only module scope unless a separately approved option changes it.
- **Shared Io/Core owner + producers:** specify native readiness/capability facts,
  distinguish connection from effect eligibility, bound startup and test queue/
  callback gating. Do not duplicate schemas or move panel editing transactions.
- **Framework owner, only if FD activation chosen:** design validated inherited
  listener construction/path ownership and test crash/backlog/dual activation.
- **Producer owners:** validate domain startup/degraded health/cleanup, retained
  D-Bus/client compatibility and persisted-state upgrade/rollback; update the Clip
  v2 package-smoke fixture before relying on it.

Completing these startup tickets still does not complete BT/NM recovery, sustained
load, process-crash coverage, matched release measurements or live/default rollout
acceptance recorded in the migration plan. Coordinator review is required.
