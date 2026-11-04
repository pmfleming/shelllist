# Bounded subscription cleanup transactions

`DaemonSessions` owns cleanup independently of view lifetime. Local control
admission failure must not discard a native subscription ID or retire healthy
consumers. This applies to the shared bridge and socket paths; the bridge remains
default. Cleanup never establishes domain success, rollback or permission to retry
an effect.

## Reserve before admission

Each session has at most **256 resource records**. Reserve a consumer release
record before attaching, and a subscription record before admitting Subscribe.
Capture physical owner serial, logical generation, consumer, local window, unique
transport ID and expected producer protocol/version. Never evict unknown records
to make room. New work fails closed when reservation capacity is exhausted.

Consumer IDs are bounded to 64 UTF-16 units, local subscription windows to 512,
native IDs to 1024 and protocol names to 128. Retained strings, including keys,
fit conservatively within 16 KiB per record / 4 MiB per session; object overhead
is bounded by record count, not claimed as a measured memory limit. No request
payload, stream content, draft, secret or private effect authority is retained.
Generated identities do not wrap.

Detaching revokes event/new-work authority before withdrawing queued data. The
view handle can then disappear without losing cleanup responsibility. A late
subscription receipt can establish cleanup ownership, never revive that view.
A pending base subscription can still be adopted by an ordinary reopen; explicit
release or retired logical/physical identity cannot be undone by a late reply.

Routed events first require the current session generation and an attached
consumer. Base/extra subscriptions then require that active consumer's live
native ID. Unrouted events with native subscription IDs are never broadcast;
only unrouted legacy events use active-consumer stream matching. These paths
share no fallback that could promote a retired subscription to broadcast work.

## Cleanup state and acknowledgement

The ledger submits at most one non-uncertain cleanup attempt at a time, through
its [reserved control capacity](shared-socket-admission.md). A shared 100 ms timer
revisits definitely never-written cleanup intent, without storing another payload
queue. Only a **leading local `UNSENT:`** Error.message/thrown string, or a routed
transport `requestUnsent`, permits another attempt. Quoted/nested diagnostic text
is not proof. Every attempt has a fresh correlation ID; an old acknowledgement
cannot complete its replacement.

After dispatch, failure, absent/mismatched receipts and lost replies remain
**uncertain and charged**. No automatic retry follows. Unknown registrations have
no eviction TTL and can exhaust admission until the physical owner retires.

Subscription adoption requires its captured route/window and a strict common
native envelope: exact protocol/version, `ok: true`, no error field, object data
and a nonempty bounded `data.subscription.id`. Invalid data cannot lend authority
over a peer's subscription. Exact cancellation success additionally requires
`data.cancelled` equal to the captured native ID and `data.kind: subscription`.
Consumer release uses the distinct raw framework `{released: N}` receipt; it is
not a domain terminal outcome and cannot discharge separately unknown resources.

A late exact success can reconcile the resource only. It cannot grant event
ownership or free uncertain socket credit. The native control deadline currently
closes its owner; detached work retains its native permit through completion.
A synthetic late success on a still-live owner is not a new final-slot protocol.

## Logical failure versus physical retirement

A protocol failure can fence consumers while leaving the physical client alive.
Keep cleanup on its captured owner/generation, including late registrations.
Only actual bridge/socket exit, or failed startup with no usable owner, clears
that owner's ledger. Replacement connections inherit no native IDs or authority.
Last-view shutdown may end the owner normally; local queue pressure must not
force peer retirement. Draining owners reject new admission rather than moving
requests to a replacement connection.

Evidence: [control cleanup integration](../tests/control-cleanup-integration.md).
Qt, native fixture and release/deployment qualification remain distinct gates.
