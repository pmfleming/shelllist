# Unix JSONL migration: stream recovery contract

The [current stream matrix](unix-jsonl-stream-matrix.md) distinguishes replacement,
delta, invalidation, historical, sample and private lifecycle streams, and records
missing recovery APIs and per-stream rollout blockers. It supersedes the archived
pre-NM audit; the implementation/evidence checkpoints below remain scoped.

## Network collection stage

`wifi.networks.changed` retains its initial/added/changed/removed payload and
adds `epoch`, `base_revision`, and `revision`. The native per-subscription
projection advances its cursor and collection together. Initial delivery is a
full baseline (`initial=true`, base 0, revision 1); subsequent deltas name the
exact revision they require. Unchanged observations do not advance the cursor.
The epoch is opaque. Counters are bounded by JavaScript's exact integer range;
exhaustion creates a new epoch and full baseline, never rounding or wrapping.

The UI accepts only events belonging to its currently acknowledged subscription.
Shared `DeltaCursor` checks ordering; it does not classify networks or decide
network policy. Duplicate/older records do not roll back state. A missing base,
malformed record or unexpected epoch suspends delta application and renews only
the network collection subscription. The new subscription supplies a fresh full
baseline. Other consumers, SecretAgent observers, in-flight operations and prompt
drafts are not retired. Control failure still fails closed without effect replay.

The network collection has a separate shared-session consumer from NM's status,
health and secret streams. This avoids a gap in credential observers when the
collection subscription is replaced. All consumers still use one daemon transport.
Late events and duplicate subscribe replies cannot adopt a retired subscription.
Attaching to an already-ready shared session establishes its subscription too.

Unversioned cache/scan collections are provisional only before a live baseline.
They cannot overwrite the collection on which subsequent deltas depend. Explicit
refresh, view warmup, scan completion and the scan watchdog can renew the live
collection without treating a read as a delta watermark or starting another scan.
A lost final record cannot be inferred until another record arrives; explicit
refresh/completion renewal also covers that quiet-stream case.

No keyboard, field transaction, validation, acknowledgement, secret authorization
or hardware guards change. Enter/Tab still save and Escape still discards locally.
No transport default is switched by this stage. Matching NM/frontend builds are
required on both transports; an old unwatermarked producer cannot supply a valid
recovery baseline, and the frontend must not weaken validation to accommodate it.

## Evidence

- NM `daemon_status/network_updates.rs`: cursor/collection consistency, skipped
  unchanged reads, loss witness, independent subscriptions, exact counter rollover,
  and actual isolated D-Bus signal emission through the production subscription.
- NM producer-owned contract fixture contains a real initial/lost/after-gap/new
  baseline sequence; only generated opaque identities are normalized.
- Qt `tst_delta_cursor.qml`, `tst_wifi_stream_recovery.qml` and
  `tst_daemon_boundary.qml`: missing/duplicate/reordered/malformed/old-epoch records,
  subscription fencing, read/scan races, other consumers, and retained prompts and
  operations. Existing domain fixture tests now acknowledge their subscriptions
  before delivering producer events rather than bypassing ownership.
- Validation at this checkpoint: 352 Qt passes, one existing renderer skip;
  95 NM library passes, three existing ignored probes; strict QML lint and
  all-target Rust Clippy pass. Generated contracts and build-input audit pass.

## NM direct ingress and bounded-loss stage

`SHELLLIST_NM_SOCKET=1` selects the production Unix adapter explicitly; Bluetooth's
existing opt-in remains independent. Neither flag changes other daemons or enables
fallback after uncertain dispatch. The matching resident daemon must already be
running: no socket activation, deployment or service restart is performed here.

NM's socket path obtains the same exported in-process object as D-Bus, using its
admission, dispatcher, worker lanes and domain coordinators. Its event destination
is transport-neutral; there is no D-Bus proxy or second NetworkManager connection.
Connection loss cancels only that owner's tasks/subscriptions/health feedback,
including existing target-guarded activation abort. Closed destinations are not
eligible secret observers. D-Bus owner reconciliation excludes socket identities.

The framework also closes two bounded-loss holes:

- Synchronous socket emission cannot block the Tokio worker needed to drain the
  output queue. Full admission retires that connection; it never grows a queue or
  silently drops the event.
- The shared pre-ack event buffer fails closed instead of evicting an initial or
  final event. The retained bridge reports the fatal error even with idle input
  and stops dispatch/ownership when its writer exits. Socket owners include fresh
  kernel entropy so persistent owner claims cannot collide merely through PID reuse.

Evidence at this checkpoint:

- 353 actual Qt passes, one renderer skip; 97 NM library passes, four ignored;
  35 framework transport passes, one ignored. Strict Clippy and QML lint pass.
- NM's private integration tests compare real D-Bus/socket dispatch and validation,
  reject foreign cancellation/status access, retain peers across disconnect, cancel
  an owned fake connect, and recreate the listener with fresh state and no replay.
- The explicitly run native NM test passes on Quickshell 0.3.0: production shared
  routing, eight reads, full baselines and independent collection renewal while the
  secret observer remains subscribed. See `tests/README.md` for reproduction.
- Bluetooth's seven-case native acceptance experiment was rerun successfully with
  a matching rebuilt bridge after the shared changes. Its debug measurement scope
  remains isolated; this does not establish NM performance or desktop-wide gains.
- NM offline contract parity, generated bindings, surface catalog and build-input
  alignment pass. The sibling-source snapshot preflight and Nix `buildInputs`
  check also pass without overrides/bypasses (Rust 1.95.0, ten locked roots).

## Bluetooth full-state ordering stage

`bluetooth.changed` and `bluetooth.audio.changed` now share `data.state` with
`bluetooth.snapshot` and `bluetooth.audio.snapshot`, respectively. Each publisher
owns an opaque epoch and positive exact revision. Payload plus watermark are one
watch value, captured atomically for both reads and events; errors/loading carry
the same metadata. Unchanged values do not advance. These are full replacements,
so coalescing may skip revisions. Counter exhaustion starts a new epoch at 1;
`previous_epoch` is retained throughout that epoch to verify coalesced rollover
without requiring delivery of the old maximum. Independent publishers never use
each other's cursor. A transport failure resets frontend cursors; route/owner
fences still reject retired-generation traffic before publication.

The shared `SnapshotCursor` rejects duplicate/older/unrelated-epoch records and
missing/malformed metadata. Boundary payload checks run before publication, and
the cursor advances only after successful synchronous publication. An old
loading/unavailable reply cannot invalidate newer state, nor can an old available
reply resurrect state after a newer outage. Explicit reads repair quiet loss of
a final full replacement; this is not a promise of periodic background liveness
checks or terminal-operation recovery.

Unwatermarked snapshots embedded in mutation acknowledgements, device operations,
scan outcomes and adapter batches no longer replace live state. Their original
acknowledgements/partial outcomes remain authoritative for the effect; a coalesced
cached-state read reconciles observations without starting another scan or
mutation. Audio mutation observations follow the same rule. Missing metadata in
an old producer fails closed on both transports, never enables raw-snapshot
fallback. Field-local drafts, confirmation, cancellation and explicit retry stay
with their existing owners.

Producer stage: BT `962f5ee` and `3e0ecb4`. Validation: 74 library passes, two private
OS-process integration passes, one ordinarily ignored native experiment; strict
all-target Clippy and formatting. New producer tests cover atomic captured reads,
coalescing, rollover lineage, and actual Unix/D-Bus success/error watermark parity.
Live-constructor fixtures normalize only generated epochs. Actual Qt tests cover
read/event races, old/duplicate/malformed records, independent audio state,
quiet-final-loss read recovery, mutation observation fencing, retained prompt
drafts and retired routes. The whole frontend suite passes **398 / one existing
renderer skip**; strict QML lint, generated contracts, BT offline contract parity,
surface catalog and build-input audit pass. The explicitly invoked seven-case
Bluetooth native Quickshell 0.3.0 experiment also passes with a matching rebuilt
bridge. Current sibling-source preflight and Nix `qmlTests`, `btDaemonContract`
(including the release BT package/tests) and `buildInputs` checks also pass.
The native experiment's debug/private scope remains unchanged; a release package
build is not a matched release performance, process-crash, sustained-load or
hardware acceptance result.

Request/pairing/scan/OBEX lifecycle snapshots are **not** ordered by these two
state cursors. Their status races and quiet terminal loss remain in the matrix.

## Application direct ingress and recovery stage

`SHELLLIST_APP_SOCKET=1` independently selects the app listener, through the same
shared session and socket adapter. The daemon reuses its exported in-process
`ServiceBoundary`, dispatcher, operation registry and event workers; no D-Bus
proxy, duplicate poller or alternative launch/settings policy is introduced.
Operation events are owner-filtered on both transports, using the status access
gate. Socket lifetime owns tasks and unfinished operations, including cleanup
when acceptance was never consumed. Other owners survive. A new owner cannot
read old private outcomes, and a crash cannot promise rollback of a handoff.

Catalog/window streams are **invalidations**, not ordered deltas. Their native
53-bit content identities are not sortable counters. Initial subscriptions,
changes and transport retirement invalidate the frontend's local read barrier.
A query/revision captured before that barrier cannot publish afterwards, even
before the debounced replacement query is dispatched. Fresh query/refresh reads
replace state; explicit refresh and view warmup repair quiet final-invalidation
loss. No missed invalidation is synthesized into a historical event.

Operation `revision` is assigned with the cached status under the producer's
operation lock, including cancellation and terminal retention (256 results, up
to 15 minutes). Its namespace is the never-reused operation ID; it is not a global
sequence, content token or transport generation. The finite phase machine keeps
it positive/exact. Actual Qt consumers reject duplicate/older observations from
reads or events, and retired operations cannot reopen. Bounded two-second status
polling (ten checks), gap-triggered status reads and explicit checks recover lost
terminal delivery without another effect. Poll exhaustion, expiry, lost admission
and connection/process loss leave outcomes uncertain, never authorize a replay.
Missing/malformed operation revisions fail closed with a matching-build error on
both transports. Conservative upstream broadcast gaps can include filtered-out
owners; they trigger only owned reads, not guessed missing transitions.

Evidence: producer library atomic-status/owner tests and private real-process
D-Bus/socket parity, unread acceptance cleanup, release, foreign ownership,
SIGKILL/restart and no-replay cases; actual Qt query/invalidation races, native
operation status/event races, duplicate/older observations, quiet loss and old
producer rejection. The real Quickshell 0.3.0 probe uses production shared routing
for eight catalog reads and subscription renewal with no application launch.
The native probe is not the deterministic Qt transport mock. Validation at this
stage: 46 producer library passes (three ignored), 16 integration passes (native
probe normally ignored, explicitly passed), 405 Qt passes and one existing skip;
strict Rust Clippy/formatting and QML lint, app generated bindings/offline parity,
surface/build-input checks, and sibling-source Nix `appDaemonContract` (including
release producer tests), `qmlTests` and `buildInputs` pass. The all-producer local
binding script reached the unchanged NM stage but required its absent debug
binary; app's binding was independently regenerated and compared successfully.
Release/load, maximum payload and cold-start/default rollout gates remain separate.

## Bar producer ingress checkpoint

Bar producer `360bcbf` adds the shared listener and transport-neutral event
destinations through the existing exported service boundary and domain state
store. No second set of monitors or policies is created. Mixed subscriptions
retain independent domain workers, and owner loss releases only that owner's
work-area demand and subscriptions. Interactive battery work observes socket
lifetime rather than D-Bus name ownership. Cancellation requests authorization
shutdown while retaining admission until durable reconciliation finishes; it is
not rollback. D-Bus callers retain the shared connection owner monitor.

Private real-socket/D-Bus tests cover dispatch/validation parity, foreign
cancellation, unrelated audio bursts and work-area ownership. A real-socket test
runs the actual battery admission coordinator with fake authorization work and
proves cancellation retains capacity until reconciliation. No hardware helper is
called. Strict all-target Clippy/formatting, offline bar contract parity and the
sibling-source Nix `barDaemonContract`, `materialGallery` and `buildInputs` pass.
The release package ran 220 library tests, 30 update-worker integration tests and
two isolated native tests, including normally ignored cases. The gallery uses
the **retained bridge**, not a bar socket: its success is compatibility evidence.

This producer-only checkpoint does not enable a frontend bar socket flag. Native
read/event ordering and domain-specific quiet loss still need qualification,
especially bounded battery/sleep/notification/OSD transitions versus current
state. Bar shared-Quickshell socket acceptance, maximum payload, sustained load,
matched release performance and OS-process-crash acceptance remain outstanding.

## Bar atomic publication and recovery stage

Every bar stream now carries `data._publication = {epoch, revision,
previous_epoch?}`; `bar.snapshot` carries the same metadata in each domain
projection. Each domain's payload and clock are captured under the existing
state-store lock, including unavailable/error publications. Revisions are
positive exact integers bounded by `2^53 - 1`. Independent entropy-backed epochs
and retained rollover lineage are not transport counters or content tokens.
Unchanged replacements do not advance; explicit history invalidations do.

The shared bar policy checks producer schemas and per-domain `SnapshotCursor`s
before admitting state. Delayed reads, duplicate/older events and unrelated
epochs cannot roll state backwards. Malformed/missing native metadata marks
that domain unavailable without consuming the valid cursor; matching producers are required
on the bridge too. Recovery is single-flight per domain, with gap barriers and
paused failures rather than unbounded retry. A cached read repairs quiet final
loss; this is an explicit refresh/warmup mechanism, not periodic monitoring.

Effect receipts remain unchanged on the wire. The producer adds an independently
captured `data.snapshot` for domains present in an effect reply; it never stamps
an earlier receipt as current. The UI retains those receipts under
`data.observations` and publishes only validated snapshots. Nested battery
completions keep their operation ownership/acknowledgement guards. `theme.resolve`
is a pure preview, while `theme.configure` reconciles current published roles.
Location acknowledgements no longer replace the activity projection; confirmed
city selection waits for that projection and yields to intervening navigation.

Full-state watches may coalesce. Battery/sleep/active-notification/hardware-OSD
streams retain their bounded transition buffers: a discontinuity or recovery read
is a `subscribed` current-state baseline, **not** replay of missing edges. Cached
state cannot reconstruct a missed sleep transition or OSD/toast history. Domain
reads and subscription renewal do not retire other consumers, accepted battery
work, or display drafts/pending preview acknowledgements. A deferred display
rollback targets the receipt's trial ID, not a newer observed trial, and connection
loss clears that pending intent instead of treating recovery as rollback authority.

Producer `8f30caa`: 221 debug library passes / two ignored; strict formatting and
all-target Clippy. The sibling-source release package passes 223 library,
30 update-worker and two isolated native tests, including ignored cases. The
frontend has 418 Qt passes / one existing renderer skip and strict lint/contracts.

Evidence: producer tests cover captured payload/clock atomicity, unchanged state,
independent domains, health failures, coalesced rollover, effect reconciliation,
and bounded transition loss. Qt tests cover inversion/duplicates/malformed clocks,
quiet loss, renewal, unrelated peers, theme previews, nested battery receipts,
display draft guards and deferred location selection. This is deterministic Qt
and private producer evidence, not native bar socket, installed-session, sustained
load, release-performance or OS-process-crash acceptance. The frontend bar socket
flag remains absent at this checkpoint.

## Bar socket opt-in and private native acceptance

`SHELLLIST_BAR_SOCKET=1` now independently selects the shared Unix adapter.
The bridge stays default; a rebuild is not selection, activation or deployment.
The matching bar daemon must already be listening. Requests, route generations,
admission credits and cancellation use the existing shared client, with no fallback
or effect replay. There is no second state producer or policy implementation.

Real Quickshell 0.3.0 passes a private production-path probe: two shared bar
consumers, eight cached reads, a new native audio publication racing an older
captured read, independent subscription renewal, consumer destruction and a ninth
read by the surviving battery/work-area observer. The producer records one owner,
three subscriptions and cancellation; work-area demand is two before renewal,
one for the surviving read and zero after frontend exit, before listener shutdown.
The exported service is in-process on a private bus; the frontend receives
nonexistent bus addresses. A test-only gate refuses effects, and no host monitors
or hardware helpers run. This is not a daemon OS-process crash experiment.

Producer fixture commit `cca6041` adds the explicit `native-quickshell-socket`
Cargo feature, separating the probe from the
bar release package's `--include-ignored` suite. Required source/Quickshell inputs
are checked, never silently treated as success. See `tests/README.md` for the
reproduction command. Default all-target Rust tests, all-target/all-feature Clippy,
formatting, strict QML lint and generated contracts pass; actual Qt reports 419
passes / one existing renderer skip. Sibling-aware Nix `barDaemonContract`,
`qmlTests`, `materialGallery` (bridge) and `buildInputs` pass; release producer
checks run 223 library, 30 update-worker and two existing isolated native cases.
The separate Quickshell socket probe passes three explicit reruns. Its evidence
is debug/private, not release
performance, maximum payload, sustained load or installed-session acceptance.

## Remaining scope

This closes NM's network delta-chain gap, not the entire multi-daemon revision
migration. Other streams' content identities/internal counters are not claimed as
uniform wire watermarks. Clipboard direct ingress, full runtime
packaging, release/mixed-load, maximum NM payload and real process-crash acceptance
remain staged work. NM's test recreates a listener, not an OS process. D-Bus remains
supported and the bridge remains the frontend default.
No deployment, live service restart, or hardware acceptance is implied.
