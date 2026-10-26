# Application runtime qualification checkpoint

2026-10-26. Scoped payload/retained-transport acceptance, **not migration or
rollout completion**. The bridge remains default; external D-Bus stays supported.
No producer/frontend policy, generated contracts or launcher behavior changed.

## Sources and fixtures

Original implementation producer: `app-daemon` `7a3d487be535954781923b37e304ddd750cf84f2`
(previous checkpoint commits `d0bb40d`, `87645a8`). Framework:
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`. Frontend baseline:
`d7a3a5e530a0fd350075f1ca85e3f83539dc6089`; this file is the only frontend change.
Rust/Cargo 1.95.0, x86_64-linux, sibling-source Nix development environment.

- `app-daemon/tests/session/socket/payload.rs`: actual daemon OS process,
  production socket ingress/admission, private external D-Bus clients and actual
  retained `app-daemon client` processes. Reuses `tests/support::Session` with an
  explicit no-activation bus configuration, synthetic desktop entries, fake
  compositor and fake UWSM handoffs. No user applications/catalog/windows.
- `app-daemon/src/daemon/socket/qualification.rs`: tracker-free synthetic catalog
  exported through the **real AppDaemon**, ServiceBoundary, API dispatcher and
  socket Service. Real private D-Bus/socket/bridge, not a mock transport or a new
  framing/policy implementation. Constructor is `cfg(test)` only.
- `app-daemon/tests/session/bridge.rs`: retained bridge exact input boundaries and
  existing two-owner/lifecycle assertions. Private child Tokio workers are now
  explicitly bounded to two; stalled-reader scenarios select one or two producer
  workers independently of the test-driver runtime.

## Tested boundaries and ownership

| Gate | Evidence |
| --- | --- |
| Socket input | Exactly **1,048,576 UTF-8 bytes**, excluding LF/CRLF, with structured multibyte params; accepted with preserved request ID/route for both terminators. |
| Bridge input | Exactly **1,048,576 bytes** of structured JSON, excluding LF; accepted and routed. |
| Oversized JSONL effect | Exactly input limit + 1, otherwise-valid launch padded with legal JSON whitespace; held unterminated while a healthy peer reads, rejected before fake handoff, then same connection reads again. Socket and bridge. |
| External D-Bus params | Exactly **1,048,576 bytes** structured params JSON accepted; +1 effect params rejected as `request-too-large` without fake handoff. This limit excludes the D-Bus envelope, unlike JSONL's complete input-record limit. |
| Effective app result | Exactly **16,777,216 bytes** of serialized service JSON accepted on external D-Bus, socket and retained bridge, with identical frozen UTF-8 catalog result. JSONL envelope/route/LF accounting checked separately. |
| Oversized app result | Same frozen service snapshot and one additional decimal generation digit: exactly **16,777,217 bytes**. All three paths return identical non-retryable `outcome-unknown`, not truncated success; subsequent reads work. No effect replay. |
| Large actual-process response | Near-16 MiB UTF-8 catalog result (64 KiB sizing headroom) survives all three paths, preserving complete synthetic comment, identity, generation and row count. Live resource samples may legitimately differ between reads. |
| Stalled native reader | Real kernel backpressure with near-16 MiB reply and production **five-second complete-record write deadline**; stalled owner's accepted fake handoff is cancelled, healthy owner's accepted fake handoff/status/reads survive and its original subscription can still be cancelled. No foreign operation events/status. Both **one-worker and two-worker daemon** cases pass. |
| Retained compatibility | Complete ordinary read/validation/unknown-method/unknown-operation response parity across private D-Bus, socket and bridge. |

The app's declared/admitted result ceiling is **16 MiB**, below the generic
socket writer's 32 MiB ceiling (including LF). These tests do **not** claim an app
endpoint can legitimately return a 32 MiB domain result. No shared limit is raised
or privately forked. Exact result sizing uses frozen input and an ordinary echoed
u64 generation; it does not change serialization, admission or output limits.

Owner retirement is cancellation, not rollback of a handoff. Missing/oversized
outcome evidence is not success or permission to retry an effect.

## Reproduction

From this family's `app-daemon` worktree. Stage any new tracked inputs with
`git add -N` first. All heavy checks require the orchestration lock/private-path
wrapper; do not run these against a desktop/session bus.

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/check.sh
"$CHECK" timeout 1200 nix develop . --no-write-lock-file \
  -c ../daemon-framework/tools/local-build develop . --command bash -c '
    set -e
    cargo fmt --check
    cargo build --locked
    SHELLLIST_APP_BRIDGE="$PWD/target/debug/app-daemon" \
      cargo test --locked --lib exact_result_limit_and_one_byte_over -- --ignored
    cargo test --locked --test session socket::payload -- --include-ignored --test-threads=1
    cargo test --locked --test session bridge::oversized_effect -- --test-threads=1
    cargo build --locked --release
    SHELLLIST_APP_BRIDGE="$PWD/target/release/app-daemon" \
      cargo test --locked --release --lib exact_result_limit_and_one_byte_over -- --ignored
    cargo test --locked --release --test session socket::payload -- --include-ignored --test-threads=1
    cargo test --locked --release --test session bridge::oversized_effect -- --test-threads=1
    cargo clippy --locked --all-targets --all-features -- -D warnings
  '
```

Do not use blanket `--include-ignored`: unrelated systemd lifetime tests require a
real manager, and existing native Quickshell tests require explicit private inputs.
The general debug regression command was:
`cargo test --locked -- --skip socket_dispatch_owner_cleanup_and_real_process_crash_are_isolated`.
The completed private SIGKILL case was intentionally not repeated.

## Results and binary identities

- General debug regression: **46 library passed / four ignored; 16 session passed /
  four ignored / one completed crash case filtered**. Real-systemd tests remain ignored.
- Explicit exact-result unit case, four payload session cases, and strengthened
  bridge case: **all passed in debug and release**.
- Formatting and strict all-target/all-feature Clippy passed. No QML/launcher code
  changed; no fresh full Qt suite or native Quickshell probe is claimed.
- Sibling-source preflight and Nix `checks.x86_64-linux.buildInputs` passed
  without overrides or preflight bypasses (`sibling-build-inputs.log`). This is
  source/toolchain alignment, not runtime-package or installed-session acceptance.
- Release tests are correctness checks, **not latency/memory measurements**.

SHA-256 (matching family builds, not binaries from original checkouts):

| Binary | SHA-256 |
| --- | --- |
| `target/debug/app-daemon` | `29606c07fb6ae4c750473593536267b8976712dab6cd31ebb72da0482aea925d` |
| `target/debug/deps/app_daemon-5184f7357964d055` (unit tests) | `94cd118b06d198c1c5079d8bd23d913f921daa79c54b3ab76cff1386dfee12e8` |
| `target/debug/deps/session-dbbee220b6193e55` | `d727c149dc8403ccb32b047cc69e60ed2ed7a8e04f19f65ac0260617c84f5239` |
| `target/release/app-daemon` | `0e659ef94f263d6aa30157182720e6c692bef93466b5711b13d21f9d8f834266` |
| `target/release/deps/app_daemon-25437ca376bfeb2e` (unit tests) | `abd0f6960bf4ad074baa22fff03a137ca03eccb5b32bb855e23e9a9fdb3d392e` |
| `target/release/deps/session-e781c096df064c69` | `87e3bd64e3402441a09c670f26f403a9c2f1cf7671f9434932f56fb928d286e9` |

Logs are under the delegated task directory
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/tasks/05-application-acceptance/artifacts/`:
`final-worker-bounded-qualification.log` (general regression, exact result,
one/two-worker cases, release and strict checks) and
`final-structured-input-qualification.log` (final structured-input debug/release
reruns and final binary identities). Source alignment can be reproduced from the
same app worktree with:

```sh
"$CHECK" timeout 900 nix develop . --no-write-lock-file -c bash -c '
  set -e
  ../daemon-framework/tools/local-build preflight ../shelllist
  ../daemon-framework/tools/local-build build --attr checks.x86_64-linux.buildInputs \
    ../shelllist --no-link --print-build-logs
'
```

An initial direct Cargo bootstrap lacked `cc`; using the Nix shell fixed the
environment. An initial full-process exact-result comparison failed because
resource sampling changed metadata/byte count between reads. The final exact case
freezes only synthetic service input; actual-process evidence deliberately leaves
headroom and checks stable fixture fields, not equality of independent telemetry.
Earlier failures remain in `initial-build.log`, `payload-debug.log` and
`maximum-diagnostic*.log`; they are not passing evidence.

## Remaining acceptance / shared-harness adoption

- Sustained mixed traffic, burst/queue overflow, many-owner fairness, maximum
  caller-controlled envelope IDs/routes and bounded-memory qualification remain.
- No new maximum/near-limit record through actual Qt/Quickshell shared routing was
  exercised. Existing small native reads/renewal remain prior evidence only.
- Bridge stalled stdout, broken-pipe/effect timing combinations and larger external
  D-Bus signal traffic are not qualified by the socket stalled-reader cases.
- Adopt the coordinator's shared-framework load harness instead of adding a second
  app framing/client implementation. Supply this private Session fixture as the
  process adapter, synthetic catalog/compositor, two fake slow targets, and
  socket/bridge/D-Bus transport selectors. Keep owner/status visibility and
  cancellation separate from replay/rollback.
- Final matched release performance is deferred until integration is stable and a
  **serial** measurement window is reserved. Rebuild matching binaries; record
  source/SHA-256/toolchain, workload and payload sizes, warmup/sample counts and
  whole process-tree scope (daemon plus retained bridge children). Use identical
  catalog/windows and read/subscription/renewal/status/cancel mix, then collect
  p50/p99 and RSS/PSS/private memory with explicit unavailable metrics. Do not infer
  whole-shell savings or use these test durations as performance measurements.
- Startup/default decisions, matched runtime packaging, installed-session upgrade/
  rollback and rollout approval remain outside this checkpoint. No service restart,
  deployment, real desktop/hardware action or production default change occurred.

## Authorized quality check/refactor follow-up

The bounded follow-up advances app source to
`21f56893316e4db765c7ba8f15918d194e54cc31` (refactor `05ef66c`, fixture worker
API documentation `21f5689`). It consolidates the duplicated private-bus
construction into `app-daemon/tests/support/private_bus.rs`, used by both the
exact-result unit fixture and the real-process Session. Private permissions,
startup deadlines and kill-on-drop ownership remain. A read-only check of the
running private bus rejects unexpected activatable service names before app
requests. No production path, limits, effects or unique boundary tests changed.

Pinned Rust Quality Lens `d28f3d936fa3c0d4c0a7ea753f436517077cb37d` measured the
same explicit `src`/`tests` scope/config before and after: hotspots, clones,
reliability, test-quality and API-health. The duplicate bus clone is gone
(64→63 clone records; 769→739 duplicated lines); Session construction decreases
151→128 SLOC / 36→31 cyclomatic, with cognitive complexity unchanged at 7.
Reliability findings stay 169 and test-quality advisories stay 20. Long explicit
maximum/+1/recovery orchestration is intentionally retained, not split for scores.

**Lens extraction remains partial**, not a universal green quality pass: baseline
`protocol/methods.rs` uses an unexpanded declaration macro. No unreadable files or
parser recovery were observed, but generated items/ownership are not certified.
Result/`anyhow::ensure` assertion helpers and explicit-only large cases explain
no-direct-assertion/ignored heuristics; no assertions, skips or thresholds were
weakened. Shelllist has no changed executable QML/JS requiring another lens.

Private general debug regression, explicit exact-result and all payload/bridge
cases in debug/release, formatting and strict Clippy passed after the refactor.
Initial Clippy found two obsolete imports from extraction; they were removed and
all relevant checks rerun. Sibling-source preflight and Nix build-input alignment
also pass after the refactor. Raw paired artifacts, config, triage, comparison,
commands and remaining findings live under the task's `quality/` directory.
Production daemon/bridge binary hashes above remain unchanged; new test SHA-256:

| Binary | SHA-256 |
| --- | --- |
| `target/debug/deps/app_daemon-5184f7357964d055` | `62a559238cdfa5f0e8721d4b2889f29a3b26d14a01a32be111b28ef5f67efa07` |
| `target/debug/deps/session-dbbee220b6193e55` | `dac57713e1aa1be5972e66ac37710363749366e26b7a28f55bfb9c7c52223c48` |
| `target/release/deps/app_daemon-25437ca376bfeb2e` | `7bb6a78c9fb232e809ec43d9e7bef83aa6f69b17cf94e374629a1e9b58dfaf51` |
| `target/release/deps/session-e781c096df064c69` | `b6a3f57f66bb05e38d063bf449d07ece2942f69a762552a35ba9ae70aabf980d` |

This review does not close any remaining acceptance above or authorize integration,
final concurrent performance measurements, deployment or rollout.
