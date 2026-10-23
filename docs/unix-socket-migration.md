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
   The other four daemons are still on the old path; step 4 is not implemented.

For the prototype only, launch an isolated Shelllist/Quickshell instance with
`SHELLLIST_BT_SOCKET=1`, using matching rebuilt Bluetooth/framework sources.
The default remains the bridge until the full rollout gate, including the stream
revision/recovery contract, is passed.
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
64 requests with a conservative 4 MiB byte cap, plus an independent 16-control /
64 KiB window. Subscriptions and cancellation use the control window. This is
admission isolation, not out-of-order delivery through Qt's write buffer.
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

## Isolated prototype evidence

[`evidence/bt-socket-prototype.json`](evidence/bt-socket-prototype.json) records
source/executable hashes, Quickshell 0.3.0, logs and raw measurements. Both Rust
artifacts used the debug profile. One private Bluetooth service with an in-memory
backend serves both paths; no real Bluetooth, desktop service or hardware is used.

| Measurement | Direct socket | Persistent client / D-Bus |
| --- | ---: | ---: |
| Cached empty-snapshot RPC p50 | 185.3 µs | 522.2 µs |
| Cached empty-snapshot RPC p99 | 307.7 µs | 953.3 µs |
| Quickshell probe + descendants PSS | 29.81 MiB | 48.35 MiB |

Latency uses the same Rust driver, alternating paths: 100 warmup calls and 2,000
measured calls per path, sequentially without pipelining. This is RPC latency,
not UI-frame latency. Memory compares separate real Quickshell runs after 50
snapshot replies with one fake adapter, including the bridge child where present.
The approximately 18.5 MiB PSS difference is frontend-group footprint, not a
whole-system saving or a five-daemon extrapolation. Separate harness samples in
the report include both paths and cannot isolate daemon-side socket overhead.
Summed RSS is recorded for diagnosis, not claimed as unique physical memory.

Seven native cases pass: fragmented UTF-8, an 8 MiB UTF-8 reply, a non-reading
peer with bounded writes/reserved control admission, real Bluetooth dispatch,
service recreation/reconnect/fresh state, and both memory configurations. The
blocked case destroys the buffered generation and verifies the replacement's
first request is new, not a replay. Restart recreates the service object, listener
and D-Bus connection **inside the test process**; it is not an OS-process kill or
live-service restart test. Mock Qt tests additionally cover lifecycle/routing,
malformed correlation, independent admission limits and failed-generation cleanup.

Real Quickshell exposed two bugs fixed in this stage: eager startup before all
component bindings were initialized, and recovery trying to gracefully drain a
failed socket. Startup now waits for component completion; failure uses immediate
retirement rather than normal shutdown. Domain malformed-reply checks remain in
place, with transport correlation rejected before releasing write credit.

Reproduce from the Shelllist checkout (Quickshell must be on PATH, or set
`QUICKSHELL_BIN` to its executable):

```sh
nix develop ../bt-daemon --no-write-lock-file --command bash -c '
  set -e
  export SHELLLIST_SOURCE="$PWD"
  cd ../bt-daemon
  cargo build --locked --bin bt-daemon
  export BT_DAEMON_BIN="$PWD/target/debug/bt-daemon"
  export SOCKET_PROBE_REPORT=/tmp/bt-socket-probe.json
  cargo test --locked --lib unix_socket_acceptance_probe -- --ignored --nocapture
'
```

The explicit ignored test owns a private bus/runtime directory, bounds child
lifetime/logs, and cleans up its own processes. Do not run the QML file standalone
against live services. The ordinary Qt suite does not substitute mocks for this
native acceptance experiment.

## Remaining acceptance and rollout

The prototype results are positive, but do not establish release-build,
whole-desktop, sustained mixed-load, maximum-payload-per-daemon, OS-process crash,
or hardware acceptance. No deployment/default switch has occurred.

The [stream audit](unix-socket-stream-audit.md) inventories every registered
stream and the missing ordering/recovery guarantees. In particular, NM network
deltas lack a base/next revision; content hashes and internal counters elsewhere
are not a uniform snapshot/event watermark. Those protocol and Qt recovery tests,
and the other four direct adapters, remain implementation work before wider
rollout. Existing explicit Bluetooth gaps and fresh snapshots do not satisfy that
cross-daemon gate by themselves.

Socket activation is deferred: it preserves a listening endpoint/new accept
queue, not already accepted connections. Reconnect and resnapshot remain necessary.
