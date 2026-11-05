# QML state ownership

Shared daemon clients expose `requestUnsent`, `ownerRetired` and `discardQueued`.
These are required parts of the internal client contract. Recording clients in
Qt tests implement the same hooks; absence is not a supported production mode.

`DaemonSessions` owns view routes, subscription publication and cleanup progress.
`SubscriptionCleanup` owns resource receipt admission and disposition. Receipt
admission requires the captured route, owner, pending/uncertain state and native
protocol/version contract. Late successful receipts confer cleanup responsibility
only. Failure/uncertainty never grants event authority or releases native credit.
Base-subscription reset has one implementation across restore, retirement and
failure. Only physical owner retirement ends uncertain resource responsibility.

Socket admission retains separate byte, queue and dispatched-credit limits for
calls and controls, including the reserved cleanup capacity. Byte arithmetic uses
JavaScript numbers without conversion to a signed 32-bit integer. Correlation
shape is shared by bridge and socket paths; wire identity and route ownership
remain socket-specific. Acknowledging a dispatched record does not rebuild its
already-removed queue entry. Queue snapshots needed for synchronous reentrancy,
serialized request capture and no-replay fences remain intact.

Notification app-page staging keeps rows, epoch, revision and offset in one
unpublished value. An owned completion consumes it once; only a validated
continuation stages another value. Rejection retains the accepted window. Final
publication owns visible rows, cursor, viewport reset and reveal completion.
Exact-app scanning can discard old staged rows without losing the next offset.
Tests deliver app pages through owned backend requests rather than calling an
acceptance helper or writing the staged state directly.

Agenda's submitted/failed field drafts use `Core.DraftStore`, through a read-only
alias. The store owns copy-on-write map updates; Agenda retains immutable begin
snapshots, request IDs, revisions, acknowledgement and explicit retry/rebase.
Bluetooth operation maps reuse the existing `BtApi` copy helpers. These changes
do not change field transactions, native key routing or domain safety guards.

Full Agenda detail replies validate document identity and catalog/cache watermarks
through the repository's shared admission predicate. The chooser separately owns
visible-summary freshness, selection and captured completion intent. Accepting a
newer inspection document never rebases an earlier completion action implicitly.
