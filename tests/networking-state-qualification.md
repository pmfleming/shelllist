# Networking full-state implementation checkpoint: Wi-Fi status

This is a **partial W1-NM implementation handoff**, not integration, quality,
rollout, startup, release-performance or all-networking completion. Bridge remains
default; socket flags are independent opt-ins. Current owned-connect retention,
revision/cancellation guards and independent collection renewal remain prerequisites.

## Implemented files and behavior

The matching producer contract is
`nm-daemon/contracts/wifi-status-observation.md`. Daemon `wifi.status` RPC and
watch payloads share one native, serialized observation owner. Actual NM capture,
in-flight signal/owner invalidation and payload/publication commit are ordered;
unavailable state has its own revision and cannot resurrect an earlier healthy
reading. Unchanged observations keep their stamp; UUID epoch rollover retains
lineage. The independent one-second RPC cache is removed rather than stamped as
authoritative current state. No latency/load improvement is claimed.

`wifi/WifiController.qml` checks native availability, clocks, radio flags and
object boundaries before using the existing shared `SnapshotCursor`. The cursor
commits before observable UI publication, fencing reentrant status delivery.
Loading/unavailable/transport retirement gives null status and no inferred powered
radio or toggle target. `WifiBackend.qml` reads status on transport-ready, and
explicit Refresh/view warmup/gaps request the same single-outstanding read.
A lost final replacement converges at those triggers; there is no production
periodic liveness timer and permanently quiet consumers may retain last valid
observations until a trigger. Failed reads require a later trigger, not replay.

Power receipts retain their message but no longer synthesize `activeStatus` via
`WifiFlow.powerStatus`; they request a fresh observation. The new status recovery never starts a
connect/scan/portal, writes NM settings, supplies/reopens credentials, or treats
link state as a connect/cancel terminal result. Accepted operations, prompt IDs,
private drafts, mixed secret/health observers and healthy consumers are retained.
Status application no longer treats unavailable as power-off or uses restored
observations to start scans; it retains accepted scan work and open drafts.
Status read success/failure cannot resume an earlier queued scan intention.
`WifiScanController` distinguishes unknown status from observed radio-off and
requires explicit retry rather than queueing a scan behind status recovery.
No Enter/Tab save, Escape discard, captured-target or UI geometry change is made.

## Evidence ownership and safety

- Native `daemon_status/observation.rs`: unchanged/unavailable identities, held
  read invalidation, concurrent capture order, exact rollover lineage and real
  subscription serialization, including unavailable state.
- Native socket/D-Bus test: production admitted reads/watch serializers; quiet
  synthetic source change repaired by read; secret-observer peer survives;
  activation, deactivation, settings, secret probe and connectivity-check effects
  remain zero. A separate private contract-witness test deliberately invokes the
  existing active-check RPC once and proves that passive status reads do not
  increment its counter; it records the API gap without using that RPC as recovery.
- Actual Qt `tst_wifi_status_recovery.qml`: initial/live/read inversions,
  duplicates/retired epochs, malformed/old producers and clocks without consuming
  recoverable revisions, quiet loss, prompt/operation/peer retention, reentrant
  publication, mutation acknowledgement separation and retired transport routes.
- Existing explicitly ignored native probe now has a third real Quickshell
  subcase (`tests/e2e/nm-status-recovery.qml`). The fixture suppresses watch delivery
  locally; after its read baseline the Rust harness changes synthetic current
  facts without a signal. A subsequent native read converges while another shared
  consumer remains healthy. This is not a dropped OS write or producer crash.
- Producer-owned offline status stream fixtures use the live serializer/clock,
  normalizing only opaque epoch identities; NM companions are regenerated from
  the matching family binary and frozen framework generator.

All NM constructors use private scripted peer/bus fixtures and a fake CommandRunner
(no subprocess networking), unavailable wireless telemetry and no host activation
service directories. Native children have cleared environments, private HOME/XDG,
offscreen/software Qt, unavailable host endpoints and no installed helper PATH.
Only explicitly isolated ignored probes are selected, never live/systemd tests.
No hardware, user apps, real clipboard, notification, deployment or service restart
is used. In-process service and mock-transport Qt evidence are complementary, not
OS-process-crash or sustained-load proof. Full nested status DTO schema enforcement
is not claimed by the bounded QML shape guard; no shared generator/runtime was forked.

## Consumers inspected and precise remaining work

| Row / consumers | Remaining contract and acceptance |
| --- | --- |
| `network.connectivity`: `WifiConnectionController.applyConnectivityEvent`, `WifiPresentation.activeConnectivity`, captive-portal/detail/list presentation | Separate watch still has no atomic clock. **The current RPC is not passive:** `Application::connectivity` invokes `Nm::connectivity_check` / D-Bus `CheckConnectivity`. The first native status fixture's peer call produced one synthetic probe (retained failed zero-probe assertion); it was replaced with `wifi.status`, not reclassified as safe. Specify a passive snapshot read before recovery, then add native ordered unavailable/current observations, read/event/gap/quiet/owner tests and consumer cursor. Preserve portal prepare/claim/complete intent; no browser/reconnect/probe as recovery. Embedded status connectivity does not order this independently preferred stream. |
| `network.inventory`: `NetworkInventoryController` plus `WifiBackend` inventory/network-status handlers | Demand subscription and `network.inventory`/`network.status` reads still race. Define separate per-projection ordering/read identities and unavailable state, close/reopen/late-read/gap/quiet tests, selected-target and activate/deactivate acknowledgement separation. A current inventory is not an uncertain activation outcome. |
| Read-only bar: `shell/SurfaceRegistry.qml` eager `statusMonitorActive`, `bar/BarController.qml.networkStatus`, `typescript/bar/BarStatusPresentation.ts` | Status now reaches the bar through ordered `activeStatus`, including ready-time reads without opening Wi-Fi. Bar still has CQ-12 Wi-Fi-vs-Ethernet/strength inference; active-with-no-AP is not Ethernet evidence. These out-of-scope files were inspected, not changed. A future paired NM/bar owner must define/consume explicit link facts. |
| `wifi.secret` / `WifiPromptController`, `WifiConnectionController` | CQ-04 private current-prompt/lifecycle reads, fixed eligible response authority, deadline/expiry/cancellation/delivery/persistence and quiet loss remain open. Never restore a closed/expired draft or transfer authority to replacement owners. CQ-05 form descriptors/normalization are explicitly excluded. |
| `wifi.scan`, `wifi.band`, `hotspot`, `vpn` controllers | Add per-operation retained ordered owner-private terminal evidence/status and quiet-final-loss coverage separately. Connect retention does not cover these. **Existing generic non-status gap fallback remains open:** `WifiController.handleDaemonEventGap` still calls `refreshNetworks(true)` after certain connect/secret/health/band gaps; `WifiRequestMetadata` correctly classifies that as an operation because it may schedule a background scan. The new status branch returns before that fallback. A separate operation/collection owner must replace the generic effectful fallback with independent read-only collection reconciliation and negative tests, not repeat effects. |
| `network.statistics` / `NetworkStatisticsController` | Native sample discontinuity/health/reset facts, dead-watch vs quiet traffic, owner/device/counter replacement and final loss remain open; do not synthesize missing samples. |
| `network.health` / `NetworkHealthController` | Filtered historical feedback/omission/owner/quiet-loss qualification remains open. Recover current facts only, never replay health notifications. |
| Wider qualification | Real producer process kill/restart, retained bridge/external-client mismatch/upgrade, maximum payloads, sustained load, TTL timing, packaged startup/readiness and stable serial release measurement remain separate. |

Global stream matrix/recovery/startup documents and shared Io/Core/generators are
coordinator-owned. Coordinator should update only the Wi-Fi status row after
review, not close connectivity/inventory or the other rows above.

**Evidenced API decision request:** the retained native failure at
`src/daemon/socket/tests/status.rs` (first run, zero-probe assertion observed 1)
shows that `network.connectivity` calls an active probe. Approve a producer-owned
passive `network.connectivity.snapshot` (proposed name), or explicitly settle
backward-compatible passive-versus-active semantics before wiring recovery.
Proposed paths: NM `src/protocol.rs`, `src/daemon_dispatch/immediate.rs`,
`src/daemon_runtime.rs` and owned registry/fixtures; Shelllist `wifi/NmApi.js`,
`wifi/NmProtocol.generated.js` and `WifiConnectionController.qml`. Keep existing
external active-check clients supported. No new method/private policy fork was
implemented by this tranche.

## Reproduction and results

All heavy checks used the run's absolute `check.sh`, bounded timeouts, private
HOME/XDG and matching sibling-source development shells. The task-local drivers
retain the exact child commands and bootstrap compiler PATH:

```sh
TASK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/02-networking-state
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh
"$CHECK" timeout 1800 bash "$TASK/run-rust.sh"
"$CHECK" timeout 1800 bash "$TASK/run-frontend.sh"
"$CHECK" timeout 600 bash "$TASK/run-qt-final.sh"
```

| Gate | Recorded implementation result |
| --- | --- |
| `cargo test --locked --all-targets` | **111 passed, zero failed, four deliberately ignored**; `rust-implementation-3.log` |
| `cargo clippy --locked --all-targets --all-features -- -D warnings`; `cargo fmt --check`; debug CLI build | Passed; same log |
| Full actual Qt 6.11.1 suite | **472 passed, zero failed, one existing renderer skip**; `qt-final.log` |
| Focused status Qt suite | 17 passed; `frontend-final.log`; also included in final full suite |
| QML lint, including new native entrypoint | Passed; final full Qt/lint/capture driver exits zero |
| Explicit `native_quickshell_nm_socket_acceptance -- --ignored --nocapture` | All three subcases pass on real Quickshell 0.3.0: shared collection/observer renewal, owned connect quiet terminal, new quiet status read; `frontend-final.log` |
| NM offline contract/registry and generated JS parity; TypeScript companion check; build-input and surface checks | Passed; `frontend-final.log` |
| Sibling preflight/development/capture | Passed for all eight family worktrees without overrides or bypasses; persistent `artifacts/implementation-capture/sources.json` and `.approval-root` |
| Nix packaged/release, process crash, sustained load and latency/memory comparison | Not run or claimed in this checkpoint |

Logs are task-local under `$TASK`. Earlier aggregate runs are retained **failures**,
not relabelled passes: `rust-implementation.log` lacked `cc` during launcher
bootstrap; `rust-implementation-2.log` had two incorrect new fixture assumptions
(off equalled the previous state; the peer's connectivity RPC actively probed).
The first Qt run in `rust-implementation-3.log` exposed ready-binding reentrancy,
a stale derived power binding and UI fixtures relying on inferred power. These
were corrected without editing shared Io, suppressing validation, deleting tests
or adding skips. `frontend-final.log` then retained one UI-fixture failure because
the initial read had not been acknowledged before its zero-write assertion;
the final routed fixture acknowledgement preserves that assertion and the full
suite passes. Its other logged gates/native subcases passed. No quality claim is
made from these functional/static checks.

Frozen baselines: NM `7f2952e8cd8b798e9e6e8182517718023eccb60f`, Shelllist
`6f14ede26d27cff03b72e51f647ee5e96dba6928`, framework
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`; no seeds. Final implementation Git
identities are in task `REPORT.md`/`result.json`. The retained source graph contains
final code/tests/fixtures; subsequent edits only fill this evidence text.

Debug binary identities (SHA-256):

- `nm-daemon/target/debug/nm-daemon`:
  `7819a123dc7710c600e45cee81f71497093ae178aaf43c63b16c4194eb852706`.
- Native library-test executable `nm-daemon/target/debug/deps/nm_daemon-42330500b18497f8`:
  `0ae59914f507d6d6dbc8de396c959edceca311ea8d035811b324b887800b7514`.
- `/nix/store/nm6wrf4gprrxlri8nr16kcmixpkk8hrf-quickshell-0.3.0/bin/quickshell`:
  `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980`.

Rust/Cargo 1.95.0, Qt 6.11.1, Quickshell 0.3.0. `qt-final.log` seals changed QML/JS
source hashes. `NmProtocol.generated.js` was regenerated using this family's
frozen framework generator and is byte-identical (registry names did not change).
The producer snapshot and frontend NM fixture were regenerated with the new
native status stream. The framework generator/local-build launcher were normally
compiled into this family's ignored targets; no shared/pinned tool source or lock
was modified. Quality BEFORE/AFTER review is a separate exact-session continuation,
not claimed here.

### Queued serial matched-release recipe (not run)

After integration freezes a matching source tuple and all workers/builds are idle,
use the same sibling-source preflight/capture and shared `check.sh timeout 1800`
lock to build release producer/frontend packages. Record source/store graphs,
compiler/Qt/Quickshell and ELF hashes. Run matched bridge and socket versions of
the private scripted status-read/watch/quiet fixture serially with identical input,
warmup, sample counts and read cadence; collect full daemon + retained bridge child
process-tree RSS/PSS/private memory and p50/p99 durations. Explicitly report missing
metrics and status serialization/cache-removal costs. Do not extrapolate this
correctness fixture or an in-process test into whole-desktop resource savings.
