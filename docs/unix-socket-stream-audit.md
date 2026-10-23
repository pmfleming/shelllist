# Subscription audit before wider socket rollout

This is an inventory of the current contracts, **not a completed revision
migration**. A reliable socket and transport generation do not supply a domain
state revision. Adding a counter only to the JSONL writer would not resolve a
snapshot reply arriving after a newer event.

## Current streams

| Producer / streams | Current delivery and recovery | Remaining revision work |
| --- | --- | --- |
| Bluetooth: `bluetooth.changed`, `bluetooth.audio.changed` | Replaceable full snapshots through watch channels; subscription publishes current state; explicit snapshot methods exist. | No uniform epoch/state-revision watermark shared by snapshot replies and events. |
| Bluetooth: `pairing.request`, `bluetooth.operation`, `bluetooth.scan`, `bluetooth.obex.transfer` | Bounded broadcasts, explicit `gap`; `bluetooth.requests.snapshot` recovers active/recent requests. Frontend gap handling requests current state, not effects. | No contiguous per-consumer delivery revision. Verify snapshot/event ordering and owner filtering when adding it. |
| Bar: `theme.changed`, `activity.changed`, `workspaces.changed`, `workarea.changed`, `compositor.changed`, `media.changed`, `audio.changed`, `brightness.changed`, `power-profile.changed`, `sleep-policy.changed`, `display-policy.changed`, `notifications.changed`, `updates.changed`, `timezone.changed` | Domain-local replaceable state; atomic snapshot-and-subscribe; initial full projection. Internal source counters measure coalescing. Some domain bodies have their own revisions. | Internal counters are not a uniform wire contract. Coalesced full replacements must not be mistaken for missing deltas. |
| Bar: `battery.changed`, `power-sleep.changed`, `notifications.active.changed`, `osd-hardware.changed` | Domain-local bounded transition history; explicit lag events; frontend stream-specific recovery. | Epoch/revision and authoritative recovery watermark still need a uniform contract; recovery cannot recreate historical edges or replay effects. |
| App: `applications.changed`, `windows.changed` | Invalidation events carrying content-derived revision tokens; lag reads current revisions; query/refresh obtains current data. | Content hashes are not monotonically increasing delivery counters. Keep content identity separate from delivery/state ordering. |
| App: `applications.operation` | Explicit broadcast `gap`; `applications.operation.status` and existing frontend polling recover known operation status. | No uniform delivery revision; preserve ownership and unknown-outcome behavior. |
| Clipboard: `clipboard.history.changed`, `clipboard.current.changed` | Reset/invalidation events; observed changes carry an event counter and a separate history token; initial/lag reset differs. History query/revision methods recover data. | Counter is not consistently present in initial/lag events and is not a snapshot watermark. History identity must remain distinct. |
| Clipboard: `clipboard.operation`, `clipboard.capture.changed`, `clipboard.session` | Explicit lifecycle/operation gaps; frontend invalidates uncertain state and refreshes capture settings where applicable. | No uniform revision or general operation-status snapshot method in the registry. Do not turn a missing terminal event into assumed success or automatic retry. |
| NM: `wifi.status`, `network.connectivity`, `network.inventory` | Immediate current state and changed full projections; corresponding read methods exist. | No uniform epoch/revision. Prove resnapshot ordering and fresh baseline on replacement subscriptions. |
| NM: `wifi.networks` | Initial/changed added/removed/changed collections calculated against the subscription's previous value; `wifi.networks` provides a fresh read. | **Delta gap risk:** no base/next revision; previous value advances before nonfatal emission. Snapshot metadata in the delta is not a replacement network collection. A missed delta needs explicit detection and resnapshot. |
| NM: `network.statistics`, `hotspot`, `vpn`, `wifi.scan`, `wifi.connect`, `wifi.band` | Request-correlated operation/sample events; operation status and domain read methods exist where applicable. | No uniform delivery revision; define recovery separately for current state, samples, and terminal outcomes without restarting effects. |
| NM: `network.health`, `wifi.secret` | External events; health is filtered per consumer; secrets retain native prompt/ownership/authorization policy. | Revision must account for filtering. Recovery must not duplicate prompts or manufacture health history. |
| NM: `daemon.request`, `daemon.subscription` | Non-subscribable, correlated cancellation acknowledgements. | Do not treat these as recoverable state streams or replay cancellation/effects to fill a sequence hole. |

## Source anchors

- Bluetooth: `src/protocol.rs`, `src/daemon/subscription.rs`, and Shelllist
  `bluetooth/BluetoothBackend.qml`.
- Bar: `src/protocol.rs`, `src/state/events.rs`,
  `src/daemon/subscriptions.rs`; Shelllist `BarDaemonBackend`/request policy.
- App: `src/protocol.rs`, `src/daemon.rs`, `src/daemon/events.rs`,
  `src/protocol/methods.rs`; Shelllist `launcher/ApplicationBackend.qml`.
- Clipboard: `src/protocol.rs`, `src/daemon/subscription.rs`; Shelllist
  `clipboard/ClipboardBackend.qml` and controller gap handling.
- NM: `src/protocol.rs`, `src/daemon_status.rs`, `src/daemon_event.rs`,
  `src/daemon_runtime/subscriptions.rs`.

Daemon paths above are relative to the corresponding sibling repository.

## Required convergence evidence

1. Define epoch/reset, monotonic state ordering, delta base revision, and
   subscription delivery ordering explicitly. A content hash, request ID, and
   transport generation are not interchangeable with these concepts.
2. Capture snapshot plus its watermark atomically with subscription establishment.
   Fence replies/events older than the accepted state and reset only on a new
   authoritative epoch/baseline. Do not rely on arrival order across RPC/event tasks.
3. Sequence after owner filtering, or explicitly represent skipped/filtered ranges;
   otherwise another consumer's events create false gaps. Full-state coalescing
   and delta loss need different handling.
4. On a real gap, stop applying dependent deltas and obtain an authoritative read.
   Preserve validation, cancellation, acknowledgement, confirmation, and secret
   handling. Uncertain effect outcomes remain uncertain; never replay them.
5. Add producer tests and actual Qt tests for missing, duplicate, reordered and
   old-epoch events, snapshot/reply races, subscriber lag, reconnect, and filtered
   multi-owner streams. Update producer fixtures/generated contracts together.

The Bluetooth transport prototype does not claim this cross-daemon gate is met.
The remaining four socket adapters and default transport switch are not yet
implemented. D-Bus remains supported and no deployed service is changed.
