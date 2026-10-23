# Direct Unix JSONL migration

## Stages and rollout gate

1. Framework foundation: `9bd377e` in daemon-framework. Same-user runtime socket,
   shared JSONL framing/correlation, bounded admission/output, connection ownership
   and late-effect cleanup. Existing D-Bus/client behavior remains supported.
2. Bluetooth prototype: daemon exports `$XDG_RUNTIME_DIR/bt-daemon.sock` alongside
   D-Bus. Both paths use the SAME exported object, service boundary, snapshots and
   coordinators. Socket subscription lifetimes replace bus-name watches; scans,
   operations and outgoing transfers are cancelled only for that connection.
3. Actual Quickshell Socket and comparative measurement acceptance. Mock transport
   tests are NOT evidence about Qt's native write buffers or large-line parser.
4. Broader rollout only after step 3, plus a revision/gap audit for every stream.
   The other four daemons are intentionally still on the old path at stage 2.

For the prototype only, launch an isolated Shelllist/Quickshell instance with
`SHELLLIST_BT_SOCKET=1`, using matching rebuilt Bluetooth/framework sources.
The default remains the bridge until the measurement/recovery gate is passed.
Do not set this on the live desktop as part of development tests. There is no
fallback to a bridge after a failed socket request: that could replay an effect.

## Frontend transport contract

`qml/Shelllist/Io/process/JsonlSocketTransport.qml` implements the existing
transport lifecycle below `JsonlDaemonClient`. The routing and domain decoders
remain unchanged. The native socket is recreated for each transport generation;
callbacks from retired objects are fenced. Failure clears unsent and in-flight
transport bookkeeping, and the shared client owns backoff and resubscription.

Quickshell 0.3 exposes neither `bytesToWrite` nor a partial-write result. Therefore
sending reserves count AND byte budgets until the corresponding response arrives:
64 requests, an independent 16-control window, and a conservative 4 MiB byte cap.
UTF-8 uses at most three bytes per UTF-16 code unit. This bounds the opaque Qt
write buffer without guessing whether a write reached the daemon. Capacity errors
happen before calling Socket.write. Per-request native Qt timers bound lost replies
without wall-clock arithmetic. Reservations are released on success OR failure
responses; no request is replayed automatically.

Graceful close sends the existing shutdown operation, continues receiving accepted
replies, and waits for shutdown acknowledgement. Reopen requests stay queued for
the next generation. A failed or stuck connection destroys its native Socket,
rather than trusting disconnectFromServer to abandon a full write buffer. The
socket adapter defers exit notification so the shared client's recovery/backoff
transaction cannot be re-entered by a synchronous native error callback.

No key handling, editable-stop model, field drafts, confirmations or hardware
safety guards change. Enter/Tab/Escape and acknowledgement fences remain governed
by the existing panel interaction contract. D-Bus stays available for external
clients and daemon-to-daemon calls. No user services are switched during tests.

## Outstanding acceptance

The required measurement report must identify build/source hashes, runtime version,
sample count, warmup and payload scope. Compare direct and bridged calls against
one isolated producer and private D-Bus, not unrelated live desktop workloads.
Measure p50/p99 and memory; do not present summed RSS as unique physical memory.
Exercise real Quickshell with fragmented Unicode, multi-MiB replies, non-reading
peers, close/reopen, daemon/listener restart and no-replay assertions.

Stream revisions are a separate required gate before wider rollout. Existing
Bluetooth broadcasts explicitly emit a gap on subscriber lag and reconnect sends
fresh full snapshots. That does NOT establish a uniform per-stream revision
contract across all daemons. Socket activation is also deferred: it preserves a
listening endpoint/new accept queue, not already accepted connections.
