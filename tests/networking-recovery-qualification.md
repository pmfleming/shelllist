# Networking recovery checkpoint: owned connect outcomes

Scope: producer-native connect observation ordering, quiet terminal read recovery,
and bounded outstanding status reads. The bridge stays default; D-Bus and legacy
clients remain supported. No live networking, service activation/restart, hardware,
credential publication, or default/packaging change is qualified here.

## Implemented behavior

See the matching producer's `contracts/wifi-connect-recovery.md`.

`wifi.connect` events and owner-filtered `operation.status` snapshots share a
per-request `operation_revision`. Registration starts at 1; progress and terminal
publication advance it atomically with the observation. The emitted event equals
the retained event. Terminal evidence is immutable. Reads use the publication and
teardown lock order, rather than checking terminal records and tasks separately.
Retention remains 256 terminal outcomes/five minutes, not a durable journal.
Expired/evicted evidence is unknown, even during terminal worker teardown; it
cannot resurrect running work or authorize cancellation of a completed link.

The actual Wi-Fi consumer validates request/stream/revision/event/status agreement,
rejects missing native metadata, and fences stale/duplicate observations. Revisions
are local to the accepted request and current owner/generation, never network
collection clocks. Cancellation intent cannot be revoked by an older read.

The existing 15-second status poll/10-second reply deadline remain. Completed read
failures stop automatic retry after three failures; explicit Check status remains.
A timed-out read keeps its identity while the operation is active; another
automatic/manual status read cannot overlap it. Shared transport admission remains
owned until actual reply/owner cleanup, even if a terminal event retires the local
recovery identity first. A late owned reply may converge. Unknown outcomes keep the accepted-operation guard. Recovery never
reconnects, submits/reopens credentials, interprets active link state as completion,
or replays health feedback. Independent collection renewal and secret observers
are unchanged. No geometry, field transaction, Enter/Tab save or Escape-discard
behavior changes.

## Evidence owners and limits

- `nm-daemon/src/daemon_runtime.rs`: private scripted-NM tests cover concurrent
  owned observations, revisions, foreign-owner absence, immutable terminal state,
  and retention eviction while teardown still holds admission. Existing deadline
  and acceptance/cancellation tests remain prerequisites.
- `nm-daemon/src/daemon/socket/tests.rs`: actual private socket status/event parity
  after deliberately not consuming terminal delivery first; repeated status is
  read-only, foreign owner gets unknown, and exactly one fake activation occurs.
- `nm-daemon/src/daemon/socket/tests/probe.rs`: the existing ignored real-Quickshell
  acceptance retains its collection/secret-observer renewal subcase and adds
  `tests/e2e/nm-connect-recovery.qml`. The new subcase makes one explicit scripted
  connect, suppresses terminal delivery using a fixture-only observer, then reads
  the native outcome through the production Wi-Fi controller/shared socket path.
  It qualifies locally simulated terminal loss, not an actual dropped OS write.
- `tests/qml/tst_wifi_connect_recovery.qml`: actual offscreen Qt covers quiet
  polling, retained outstanding reads/deadlines, stale/duplicate/reordered events,
  malformed/foreign/old-producer status, cancellation races, bounded completed-read
  failures, private draft/observer retention, terminal retirement and reconnect
  fences. Recording transport is not native socket evidence.
- `tests/qml/tst_wifi_operations.qml` and `tst_wifi_stream_recovery.qml`: existing
  actual command/credential/collection prerequisites with matching revisions.

All native services are in-process fixtures. FakeNm uses private peer connections,
a scripted CommandRunner (no subprocess effects), unavailable wireless telemetry,
and a private bus with no activation service directories. Qt runs offscreen with
private HOME/config/cache/runtime and unavailable host buses/compositor. The native
child may use its explicit private test bus only. Neither fixture is a daemon
OS-process-crash, sustained-load, maximum-payload, release-performance, installed
session, hardware or startup/default acceptance result.

## Remaining rows (not implemented by this checkpoint)

| Row | Current boundary / precise next acceptance |
| --- | --- |
| `wifi.status` read/watch | `daemon_status.rs` emits coalesced replacement payloads; cached RPC replies have no common authoritative watch/read stamp. Add atomic native read/watch ordering, stale-read/event/old-owner/malformed rejection and quiet current-state repair. Do not borrow collection revisions or let status authorize connection success. |
| `network.connectivity` | Passive full observations are separate from connect outcomes; same native read/watch race and quiet-loss gate as status. Preserve portal intent/claim authority; connectivity is not permission to reopen a browser or reconnect. |
| `network.inventory` / network state | Demand-owned extra subscription plus independent reads (`NetworkInventoryController.qml`) can race. Establish native per-domain publication ordering and consumer fences while preserving selected targets and owned subscription lifetime. Reconcile current inventory only, never repeat activate/deactivate. |
| `network.statistics` | Rates are computed natively from adjacent producer samples; frontend gap handling currently keeps the old sample. Add native sample identity/discontinuity/reset semantics without fabricating holes, and clear/mark stale presentation. The watch has running status but no retained terminal outcome; qualify dead-watch versus quiet traffic, device/NM-owner replacement, counter reset and final-event loss. |
| `wifi.scan` | Request-correlated snapshots/complete/error are not the collection cursor. No retained terminal result through the connect-only store path. Add owned outcome retention/order/read recovery and distinguish complete/cancelled/unknown without starting a scan as recovery. Preserve independent collection renewal and active scan guards. |
| `wifi.band` | No retained terminal store/frontend status reconciliation comparable to connect. Add owned outcome evidence, ordering and final-event-loss qualification; a band read is observation, not proof of an uncertain setting effect. |
| `hotspot` | Current-state refresh exists, but no retained owned terminal outcome/status consumer path comparable to connect. Add lifecycle order/read reconciliation and quiet terminal tests without restarting hotspot. |
| `vpn` | Same owned terminal/status gap; VPN status/list reads are not evidence of an uncertain connect outcome. Add retention, races, cancellation and quiet terminal coverage without reconnect. |
| `network.health` | Native monotonic owner-filtered recommendation/deduplication remains authoritative historical feedback. There is no recoverable event log or sequence contract. Qualify omission/coalescing/owner boundaries and quiet loss explicitly; recover current state only, never synthesize/replay missed notifications. |
| `wifi.secret` | Existing fixed eligible-owner response authority, live deadline, NM-owner fencing and separate observer remain prerequisites. No authoritative private current-prompt/lifecycle read API exists. Audit queued publication versus cancellation/expiry and late-subscriber observation versus fixed response authority; future reads must be read-only, fixed-eligible-owner filtered, and must never reopen a locally closed/expired form or supply credentials. Missing receipt remains unconfirmed. |
| Connect beyond this tranche | Broader disconnect-before-acceptance/terminal delivery and real daemon OS-process-kill/restart, retention TTL timing (eviction is covered here), producer mismatch/upgrade and load qualification remain. Lost acceptance gives no recovery ID; old owner/generation cannot be resumed. There is no durable outcome journal or automatic connect retry. |

Global stream matrix/recovery documents are outside this worker's edit scope; the
coordinator should record only this narrow connect checkpoint after review, not
close the remaining NM rows.

## Reproduction and recorded results

Run from this isolated sibling family, through the orchestration `check.sh` lock.
Bootstrap the local-build launcher using the matching frozen framework development
environment when Cargo is not on PATH; do not bypass sibling preflight:

```sh
# From shelllist; CHECK is the orchestration's absolute check.sh path.
"$CHECK" nix develop ../daemon-framework --no-write-lock-file -c \
  ../daemon-framework/tools/local-build develop . --command bash -c '
    set -e
    export QT_QPA_PLATFORMTHEME=""
    tests/run-qmlquality-tests.sh -input tests/qml/tst_wifi_connect_recovery.qml -o -,txt
    tests/run-qmlquality-tests.sh -input tests/qml/tst_wifi_operations.qml -o -,txt
    tests/run-qmlquality-tests.sh -input tests/qml/tst_wifi_stream_recovery.qml -o -,txt
    tests/run-qmllint.sh
  '
"$CHECK" nix develop ../daemon-framework --no-write-lock-file -c \
  ../daemon-framework/tools/local-build develop . --command bash -c '
    set -e
    export SHELLLIST_SOURCE="$PWD"
    export QUICKSHELL_BIN="$(command -v quickshell)"
    cd ../nm-daemon
    cargo test --locked --all-targets
    cargo test --locked --lib native_quickshell_nm_socket_acceptance -- --ignored --nocapture
    cargo build --locked --bin nm-daemon
    cargo clippy --locked --all-targets -- -D warnings
    cargo fmt --check
    cd ../shelllist
    cargo xtask contract nm --bin ../nm-daemon/target/debug/nm-daemon
    node tests/check-generated-contracts.js
  '
```

### Recorded results (2026-10-26)

| Gate | Result |
| --- | --- |
| Producer ordinary all-target tests | 102 library passed; four existing ignored; other binary targets contain no tests |
| Explicit real Quickshell 0.3.0 probe | Both collection renewal and quiet-terminal recovery subcases passed; hardened environment rerun passed |
| Full actual Qt 6.11.1 suite | **449 passed, zero failed, one existing renderer skip**, including 20 recovery-suite entries |
| Strict QML lint | Passed |
| Producer strict all-target Clippy and formatting | Passed |
| Offline NM contract/registry parity and generated contracts | Passed |
| Sibling-source preflight/development environments | Passed without source overrides or source-check bypasses |
| Build-input and surface catalog checks | Passed |
| Release Nix package/runtime, process crash, load/performance | Not run; not claimed |

Final source identities: nm-daemon `cf10554ef25661254ee55e48e9b91eb9d017aedf`;
daemon-framework `563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`; Shelllist implementation
is in the commit containing this record (baseline
`d7a3a5e530a0fd350075f1ca85e3f83539dc6089`). Final native input SHA-256:

```text
4a9934f286fde1c7f5946396dbe53f7ce24d7af1fab584c107ee89f595ebaae7  wifi/WifiConnectionController.qml
f563391216aadbc619fda69b0c241a91163a95d182122d14e6b6ad58281f45e6  tests/e2e/nm-connect-recovery.qml
3d5bf5c4ff493deb5b4313ba10757531482bf711f866b40c6de78c8c9fd8dee9  tests/qml/tst_wifi_connect_recovery.qml
```

Binaries were freshly built in this isolated family, not copied from an original
checkout. Final native Rust library-test executable:
`nm-daemon/target/debug/deps/nm_daemon-17f2e080fa5882dc`, SHA-256
`ebf1322a349e07df204c87951b1a101cb1080b4ebbbf8b8881d230f91415e70f`.
Quickshell: `/nix/store/nm6wrf4gprrxlri8nr16kcmixpkk8hrf-quickshell-0.3.0/bin/quickshell`,
SHA-256 `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980`.
Offline producer CLI: `nm-daemon/target/debug/nm-daemon`, SHA-256
`fbee458f993be7b42309ca06ab7bd949dcfe00236a2ccc50f5af7ea893a57a7b`.

Local logs (not uploaded) are under
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/tasks/02-networking-recovery/artifacts/`:
`producer-native-final.log` (all-target/first native/contract checks),
`qt-focused-isolated.log` (focused Qt/lint), and `final-qualification.log`
(full Qt/lint/build-input/surface/generated checks and hardened native/Clippy rerun).
The final frontend command replaces the focused invocations above with
`tests/run-qml-tests.sh`, then lint, `cargo xtask build-inputs`,
`cargo xtask surfaces --check` and generated checks; it then runs the explicit
native producer probe and strict Clippy/formatting.

Setup failures are retained honestly: `producer-initial.log` failed before build
because the launcher had no Cargo on PATH; a snapshot preflight in
`qt-focused.log` refused an unstaged new contract; `qt-focused-final.log` failed
before Qt tests because an inherited GTK theme plugin tried to use a nonexistent
display. Framework bootstrap, `git add -N` and empty `QT_QPA_PLATFORMTHEME`
respectively fixed these without installation, live endpoints or bypasses.
