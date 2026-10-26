# Wave 1 coordinator integration — framework and application

Run `20261026T202406Z`, first bounded integration batch. All six implementation
and exact-session quality handoffs have arrived; handoff status is not approval.
Only the framework and application checkpoints below are integrated here.
Bridge remains default; no deployment, live service/hardware action, startup
selection, final performance measurement or rollout approval occurred.

## Reviewed source and scope

| Component | Implementation lineage | Separate quality | Coordinator integration |
| --- | --- | --- | --- |
| Framework | inherited `48cb4c2`, fresh `e029103` | `cf90ebc` | `aeb58d3` |
| Application producer tests | `b76bc15` | `0b0f041` | `2e1ac24` |
| Application frontend | `27c41a1` | `89a3f1c` | commit containing this record |

The full original-baseline inventories were reviewed: seven framework files and
11 application/frontend files, including inherited support, tests and evidence.
Producer index trees exactly matched the final worker trees before integration;
all eight frontend changed-file blobs matched the final worker. Every check was
fenced by the eight-repository HEAD/index/worktree seal. Coordinator additions
after checks are documentation only; executable bytes remain unchanged.
Original implementation/quality commits and handoffs remain in their worktrees
and archives. Coordinator commits aggregate reviewed changes, not worker approval.

Framework supplies test-only bounded mixed-owner qualification support, explicit
traffic/percentile/memory/source identities and real-private-socket correctness
self-tests. Identity commands bound output/time and kill/reap their direct child;
the refactor retains one deadline after stdout EOF and a live-child regression.
Its trusted non-spawning Git/coreutils restriction is not generic process-tree
containment. Producer adapter adoption, full process-tree measurement and final
exclusive serial release qualification remain open. No production transport API,
policy, dependency or limit changed.

Application CQ-15 captures the canonical submitted action for Close no-handoff
rather than reclassifying presentation prefixes. Request identity/target capture,
uncertainty, explicit retry and native validation remain authoritative. Existing
Qt cases gain malformed/late/reopened/recovered vectors. The existing private
actual-process/Quickshell probe now verifies near-16-MiB UTF-8 read delivery through
shared frontend routing, a healthy logical consumer and an independent subscribed
socket peer, without launching an application. Its private child is explicitly
killed/reaped on timeout/I/O error, with a bounded timeout regression.
This does not qualify exact frontend ceilings, maximum whole-panel rendering,
large effect receipts, broken-pipe effect timing, packaged startup or performance.

## Actual quality loops, not universal certifications

Both checkpoints have real BEFORE → review/refactor → AFTER → affected checks →
separate nonempty quality commit → clean-head AFTER evidence.

- Framework Rust extraction completed for authored syntax, including nested test
  support. The identity-command handshake is simpler without weakening bounds or
  cleanup. Disabled semantic identity, unexpanded cfg/macros, unmeasured architecture
  and test-value/coverage limits remain. No whole-project semantic pass is claimed.
- Application Rust/QML loops completed, but extraction remains **partial**. Rust's
  unchanged `declare_methods!` omits generated items/ownership. QML has 24 unresolved
  imports, 48 unresolved types and 443 skipped semantic evaluations. The native
  signal-boundary annotation addresses one finding; explicit Rust child ownership
  appropriately increases complexity. Remaining findings are retained, not hidden.
- Application's report labels `b6443d…` a QML CLI hash; it is actually the aggregate
  **dist-JS** digest defined by the verified tool-reuse provenance, not a single
  entrypoint hash. Original evidence is preserved; this records the scope correction.
- Pinned analyzer-managed locked Rust helper compilation in private caches actually
  occurred and was authorized. Tool sources/main binaries/locks were unchanged.
  New coordinator driver checks were Bash syntax and Python AST plus execution;
  neither Lens is claimed to certify Python/shell orchestration.

Partial static evidence is accepted only for these inspected bounded changes,
with functional evidence and retained limits—not relabeled a semantic pass.
See [application implementation](application-frontend-acceptance.md),
[application quality](application-frontend-quality.md), and the framework's
`tests/private-qualification.md` / `contracts/private-qualification.md`.

## Matching serialized integration checks

All seven driver steps exited zero, using the current run's shared `check.sh`
lock, private HOME/XDG, unavailable host endpoints, offscreen/software Qt and two
build workers. Source capture/preflight and matching sibling dev shells were used;
no installed stale producer binary, source override or preflight bypass.

- Rust/Cargo 1.95.0: framework **73 workspace passes**, one existing profile ignore;
  application **46 library + 18 session passes**. Formatting and strict all-target/
  all-feature Clippy passed. Unrelated explicit-only probes stayed ignored.
- Existing exact-result, four payload and oversized-effect bridge cases passed.
  Native ordinary/large frontend acceptance passed **twice**; UTF-8 payloads were
  16,707,950 and 16,707,951 bytes with metadata headroom below the 16-MiB result cap.
- Qt 6.11.1 / Quickshell 0.3.0: **469 Qt passes, zero failures, one existing renderer
  skip**, both development and matching Nix. Lint, generated-contract negatives,
  surface catalog and build-input checks passed.
- Matching Nix `frameworkWorkspace`, `appDaemonContract`, `qmlTests`, `buildInputs`
  passed. Framework reused its matching checked output; application rebuilt and
  passed 46 library + 18 session tests. The unchanged bar dependency rebuilt for
  QML and passed 228 library + 30 update-worker + two native integration tests.
  This does not integrate or approve the separate bar semantic-facts worker.

Evidence root: `/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/integration-review/`.
It contains
`first-batch-stage.json`, `first-batch/source-seal.json`, source capture, seven logs,
`first-batch/result.json`, native self-test identities and the explicit drivers.
These are correctness checks, not an idle-window latency/memory benchmark.

## Withheld and unfinished work

- **BT withheld:** final quality executable bytes equal the two coordinator actual-Qt
  negative witnesses. Aggregate recovery grants unacknowledged peer-consumer cancel
  authority; recovered completion discards an unrelated same-device pairing draft.
  Fresh Rust/QML extraction exists but did not resolve these defects. A separate
  focused repair/check/commit/quality/commit checkpoint is required. The exact
  canonical offline fixture edge is explicitly retained as architecture debt, not
  a policy-rule pass; rules and raw errors remain unchanged.
- NM, clipboard package and bar handoffs remain **unintegrated pending coordinator
  review**. NM covers `wifi.status`, not all connectivity/inventory rows. Clipboard
  Python review is not a Lens pass or real packaged-main acceptance. Bar CQ-10
  upstream missing/nonfinite acquisition validity remains explicitly unfinished.
- Remaining lifecycle/schema/conversion waves, producer qualification adapters,
  startup decisions, native crash/large-effect journeys, sustained load/fairness,
  exclusive serial matched-release measurements and separate rollout approval stay
  in the [completion plan](../contracts/project-completion-plan.md).
