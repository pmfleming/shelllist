# Unix JSONL migration: stream recovery contract

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
No transport default is switched by this stage.

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

## Remaining scope

This closes NM's network delta-chain gap, not the entire multi-daemon revision
migration. Other streams' content identities/internal counters are not claimed as
uniform wire watermarks. Direct adapters, matching packaging, release/mixed-load
and real process-crash acceptance remain staged work. D-Bus remains supported.
No deployment, live service restart, or hardware acceptance is implied.
