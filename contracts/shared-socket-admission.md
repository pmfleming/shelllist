# Shared socket admission

The bridge remains default; all five socket flags remain independent opt-ins.
No activation, compatibility handshake, fallback, effect retry or native ceiling
changes are introduced by this contract.

## One bounded window per socket owner

The shared socket adapter charges **Call and Subscribe** to the same data lane,
as the native framework does. Cancel/Release use a separate control lane.
Shutdown retains its existing drain path.

| Budget | Clipboard | Other daemons |
| --- | ---: | ---: |
| Dispatched Call + Subscribe | 4 | 64 |
| Dispatched Cancel + Release | 16 | 16 |
| Data reservation | `3 * (128 MiB + 1)` | 4 MiB |
| Control reservation | 64 KiB | 64 KiB |
| Waiting data / controls | 256 / 16 | 256 / 16 |

Reservations cover queued and dispatched records, conservatively counting three
bytes per emitted UTF-16 unit including LF. They do not raise producer frame
limits. Within the existing control budget, ordinary controls may use 15 dispatched
slots, 15 waiting entries and 40 KiB. One slot/entry and 24 KiB remain reserved for
[exact-resource cleanup](subscription-cleanup.md). Blocked data cannot block that
cleanup lane. No second socket startup payload queue exists.

Waiting expires after five seconds; connection timeout is five seconds and
acknowledgement/shutdown timeout is 35 seconds. The captured waiting deadline is
checked before first write even if Qt has not delivered its overdue timer callback.
`Date.now()` plus Qt Timer is not a monotonic-clock proof: a wall-clock rollback
combined with delayed timer delivery remains a limitation.

## Identity and outcomes

Serialization captures params and route before waiting. Each attempt receives a
fresh private wire ID; only its exact response restores the original local ID.
Duplicate/unknown/never-written responses cannot free credit or reach a consumer.
Malformed correlated replies and route mismatches retire the suspect connection,
without replaying its queue.

Both transport paths use `JsonlRouting.responsePayloadValid`: success carries a
non-array object; failure carries a string error and a recognized rejection or
unknown outcome. The bridge also requires a nonempty string ID and boolean `ok`
before acknowledging a request or resetting retry health. Invalid bridge data
uses its existing protocol-error recovery policy. Socket correlation, route and
late-resource checks still precede publication; unknown or never-written wire
IDs cannot grant ownership by supplying a well-shaped payload.

Local count/byte rejection throws `UNSENT:`. Waiting expiry, consumer withdrawal
and shutdown deliver routed `requestUnsent` for definitely never-written work.
The backend uses its existing `sendFailed` path, not a dispatched uncertainty or
success receipt. No new effect is submitted automatically. Consumer deactivation
withdraws queued data, not already dispatched work.

An `outcome-unknown` receipt does not prove that accepted native work or its permit
ended. Retain its byte/slot credit and original acknowledgement deadline until
physical retirement. One late subscription/cleanup receipt may establish cleanup
responsibility, but cannot release uncertain physical credit, restore view
identity or authorize another effect. Cancellation is not rollback.

## Reentrant completion

Pending entries are identity tokens. Capture submitted metadata and consume the
original policy transaction before notifying callbacks that may reuse a local ID.
Response/send-failure handlers see the completing request's metadata; cleanup may
remove only that exact pending window. A policy or public callback's explicit
replacement keeps its pending state and metadata, including when the old handler
consumes its metadata. No domain result-schema hook is added in this repair.

Executable evidence: [control cleanup integration](../tests/control-cleanup-integration.md).
