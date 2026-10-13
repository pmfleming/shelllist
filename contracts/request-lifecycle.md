# P4 request and authorization lifecycle

## Bridge outcomes

The existing JSONL response shape is retained. Request-scoped failures have
`ok: false`, the original `id`/`route`, a human-readable `error`, and an additive
`outcome`:

- `rejected-before-dispatch`: bridge admission, connection setup, or event-reader
  readiness failed before sending the request. This is not an automatic retry
  instruction.
- `outcome-unknown`: an ordinary Call exceeded 30 seconds, lost its reply, or
  returned an undecodable reply. No effect is replayed. Reconcile domain state.
- Domain failures remain valid daemon API envelopes inside successful transport
  responses. They are not connection failures.
- `transport-generation-failure` accompanies `kind: transport-error`. Owner
  replacement, failed event forwarding, and admitted subscription/control
  deadlines retain generation recovery. The UI terminates the old bridge,
  disconnecting its owner and releasing owner-scoped server work.

Ordinary expiry does **not** reset correlation, replace the connection, emit a
transport-error, or fail another consumer. Legacy `call_failure` configuration
is retained for source compatibility but cannot relabel uncertain Call failures
as proven daemon unavailability. The bridge's D-Bus connection uses a 60-second
inner timeout so zbus' former 25-second default cannot preempt the 30-second
bridge deadline. This does not change unrelated system-bus clients.

Subscription readiness has a separate five-second pre-dispatch budget. After
Subscribe is sent, its 30-second deadline is conservative: generation recovery
is mandatory, not a claim that dropping the wait cancelled the subscription.
Cancel/Release retain five-second recovery deadlines. Private-bus tests create
a subscription *after* the old client disconnects and verify owner cleanup.
Connection-preserving late-reply cleanup is deliberately not enabled.

## Battery authorization operations

Additive bar-api v1 methods:

- `battery.operation.start { method, params }`: accepts one of setThresholds,
  setProtection, chargeOnce, setChargingInhibited, startCalibration or
  cancelCalibration. Returns `data.operation` promptly, without waiting for
  authorization. A running acknowledgement is **not** hardware completion.
- `battery.operation.status { operation_id }`: returns running/finished state;
  a finished operation contains the original battery API response, including
  partial readback and domain failures.
- `battery.operation.cancel { operation_id }`: acknowledges cancellation intent.
  It never promises rollback or reports a dispatched write as cancelled.

IDs include the bus GUID, service unique name and a counter; service/bus restart
cannot alias a prior operation. Status/cancel use the actual D-Bus sender, not
frontend route metadata. There is one active interactive battery operation
across owners and at most 64 retained records. Terminal results are readable
for five minutes; expired entries are pruned on admission. Running owner loss
requests cancellation and removes its record when work settles. No recovery
capability crosses owners or daemon restart.

The operation deadline requests cancellation after 300 monotonic seconds; it
does not abort persistence/rollback halfway through. Each interactive helper
call has a dedicated connection and a 100-second client budget. The privileged
helper bounds polkit authorization at 90 seconds, sends a unique polkit
cancellation ID, and cancels it on deadline/owner loss. It checks owner presence
again immediately before the synchronous writer. Cleanup is bounded at two
seconds. Once writing begins, cancellation/disconnection can race completion:
that result is unknown until read back, never assumed undone.

Automatic policy and legacy immediate battery API calls use new noninteractive
helper methods (polkit flags 0), with three-second authorization and five-second
helper-call budgets. Idle/sleep authorization remains noninteractive. The
shared system-bus three-second default is unchanged. No machine policy was
modified to test an interactive policy variant.

An uncertain helper write persists a per-battery no-replay fence in the runtime
record. The monitor still reads/decorates actual hardware but pauses ordinary
automatic writes. Calibration restoration and due charge-once restoration
remain safety actions; the uncertain calibration **start** is not replayed.
An explicit, confirmed hardware action clears only that battery's fence while
holding the effects lock. Hardware uncertainty does not erase durable recovery
information. File-system failures are surfaced, not reported as clean rollback.

The QML backend polls only status, not start. It keeps existing controller busy
and revision guards until the terminal response, then requests a snapshot.
A separate operation-lifetime context in the shared bar recovery policy fences
terminal battery projections against pushes received since start: a stale
projection is discarded without discarding the operation acknowledgement.
Cancellation acknowledgement leaves it pending. Lost acknowledgement, lost
owner, malformed status, or the six-minute frontend wait limit produces unknown
outcome and read-only reconciliation, never automatic effect retry. Durable
charge/calibration state outlives the short authorization operation.

## Compatibility and rollout

Existing immediate reply/event shapes remain unchanged; new methods are
additive. Older UIs can use immediate methods under noninteractive policy.
A new UI against an older daemon receives an unsupported-method failure and
must not silently fall back to an immediate effect. Upgrade/rollback the UI,
bridge, daemon and privileged helper together for interactive support. An old
helper cannot service new noninteractive members and fails conservatively.
Before rolling back to a build that predates uncertainty fences, reconcile or
complete pending hardware restoration with the new build; do not discard its
runtime record or assume an older monitor understands the new fence fields.
Same-user session code remains trusted; owner isolation is not an executable
allowlist or an application sandbox.

## Evidence

- Framework private-bus tests: slow applied Call alongside a healthy Call,
  domain failure, same-connection progress after expiry, no replay, readiness
  rejection and late subscription cleanup after old-owner disconnection.
- Real battery helper with fake polkit and temporary BAT0: successful 3.2-second
  authorization, noninteractive challenge rejection, owner-loss cancellation
  and no late write. Apply-then-withhold-reply and apply-then-disconnect both
  report unknown; isolated hardware readback verifies exactly one application.
- Operation store tests: bounded admission, immediate acknowledgement, status
  retention, owner isolation, cancellation intent and running-owner cleanup.
- Production-generated operation fixtures drive native QML acknowledgement,
  partial/failure/completion, cancellation, status-timeout and reconnect tests.
- Debug-build cost sample (1,000 iterations, private bus): proxy construction
  4.105 ms; serialization of a roughly 9 KB JSON payload 533.141 ms. This is not
  an end-to-end performance claim or a release benchmark. No proxy cache was
  added: generation/signal ownership complexity is not justified by this sample.

See `architecture-execution.html` for final test results and remaining gates.
