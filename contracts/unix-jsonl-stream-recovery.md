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

## Remaining scope

This closes NM's network delta-chain gap, not the entire multi-daemon revision
migration. Other streams' content identities/internal counters are not claimed as
uniform wire watermarks. Bar, app and clipboard direct adapters, full runtime
packaging, release/mixed-load, maximum NM payload and real process-crash acceptance
remain staged work. NM's test recreates a listener, not an OS process. D-Bus remains
supported and the bridge remains the frontend default.
No deployment, live service restart, or hardware acceptance is implied.
