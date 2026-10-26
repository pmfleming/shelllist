# Worker integration review — 2026-10-26

Scope: coordinator review of completed run `20261026T142325Z` checkpoints, including
required quality check/refactor handoffs. Bridge remains default; no service,
hardware, clipboard, installation, startup-policy or rollout change is authorized.

## Review decisions

| Lane | Reviewed worker heads | Disposition |
| --- | --- | --- |
| Networking | nm-daemon `cf10554` + `e1ec520`; Shelllist `084de6c` + `cff6d46` | Accept the bounded owned-connect recovery/refactor, not all networking recovery. Reviewed atomic lock ordering, immutable retained terminals/eviction, owner filtering, monotone cancellation, status-read lifetime and native/Qt safety fixtures. |
| Clipboard crash | clip-daemon `510d557` + `cbbd97d`; Shelllist `bf76ec6` + `b54a10c` | Accept the test-only exported-service OS-process fixture and actual Qt generation/draft regressions. Reviewed independent fake async backend, private no-activation bus, cleared child environment/fake helper, process drop order, retained admission and no-replay assertions. |
| Bar runtime | bar-daemon `b9469e8` + `4e84c74`; Shelllist `815b743` + `4999027` | Accept the test-only lib-test process/payload fixture. Reviewed allowlist before dispatch, actual battery coordinator ownership, production snapshot/subscription serializers, isolated constructors, layered limits and stalled-owner reconciliation. |
| Conversion audit | Shelllist `46ee7b3` | Accept the frozen-source responsibility inventory and 15 bounded tickets as planning, not permission to implement conversions. Retain Core/Model, update read transactions and legitimate QML state; clarify the contributor contract's explicit continuous-preview exception. |
| Startup/readiness | Shelllist reviewed integration `c06890e` | Already reviewed/committed separately; strategy still undecided. See [startup review](startup-readiness-review.md). |
| Shared qualification | daemon-framework `4238b1b` | **Not integrated.** Required Lens extraction never completed: worker's no-tool-rebuild interpretation blocked analyzer-managed helper compilation. Functional tests are not a substitute for that missing quality loop. |
| Bluetooth | bt-daemon `54532b2`; Shelllist `1bcdca7` | **Not integrated.** Final quality handoff arrived during review: QML loop completed, but Rust extraction was blocked by the same helper-build restriction. Global BT fixture/parity work also remains. |
| Application | app-daemon `d0bb40d`, `87645a8`, `7a3d487`, `05ef66c`, `21f5689`; Shelllist `63a5885`, `05011f9` | Final quality handoff arrived during review. Accept the test-only exact/near-limit socket/bridge/D-Bus and one/two-worker stalled-reader fixtures, including the shared no-activation bus refactor. Reviewed actual admission, cfg(test)-only catalog injection, worker configuration, cleanup guards and sizing limits. |

Worker hashes identify review inputs, not necessarily the integrated commit IDs.
Production changes in this checkpoint are confined to NM connect observation/status
and its Wi-Fi consumer. Clipboard/bar/application additions are test-only. No shared Io/Core,
framework transport, startup units, flakes or lockfiles were changed. All four
producer/frontend pairs are reviewed with their quality refactors, not just their
initial implementation commits.

## Quality evidence is not one boolean score

Networking completed its review with explicit authored-syntax/semantic limitations:
79 unresolved QML references and Rust unexpanded-macro/disabled-semantic identity
remain partial. Its refactors reuse validated event phase classification and one
store-before-deliver terminal publication path. The reports do not claim all 275
QML or existing Rust advisory findings are resolved.

Clipboard, bar and application reported `partial` conservatively after actually running both
required BEFORE/AFTER phases, triaging findings, making scoped refactors and passing
affected executable checks. Coordinator review accepts those **bounded checkpoints**:

- Clipboard: 16 unresolved QML imports/types and 72 skipped semantic evaluations
  remain partial; actual lint/Qt tests do not turn them into complete analysis.
  Shared process ownership and bounded diagnostics improve the fixture; the fresh
  subscription acknowledgement assertion now proves its stated invariant.
- Bar: automatic test discovery includes unchanged Wayland macros; test-quality
  extraction remains partial. Three test-only helpers are reported as production
  by the narrow-root attribution. Raw findings are retained, not suppressed.
  The shared acceptance-receipt helper never derives IDs from observed state.
- Application: an unchanged `declare_methods!` macro keeps all static envelopes
  partial; no generated-item/compiler-ownership completeness is claimed. Shared
  private bus setup removes the introduced duplicate and checks actual activation
  names. Exact result phases remain explicit rather than split for heuristic scores.

This is an explicit semantic review disposition, **not** rewriting missing evidence
as a pass, disabling a quality rule, or asserting global semantic/compiler coverage.
Neither lane requests such a global certification. The framework lane is different:
no analyzer findings were extracted, so its required loop remains blocked. Bluetooth
also lacks required Rust extraction despite its completed QML loop.

**Tool-provisioning clarification and provenance correction:** the no-tool-rebuild
instruction was interpreted inconsistently. Coordinator review accepts normal
analyzer-managed `--locked` helper compilation from the unchanged pinned manifest
into private caches, not replacement/rebuilding of the pinned CLI or tool sources.
Clipboard/bar/application disclose this cache provisioning. Networking's blanket
"no helper build" statement is inaccurate: the pinned helper dispatcher invokes
Cargo, and its private caches contain `rust_facts`. Pinned tool worktrees remained
clean and the CLI hash unchanged; helper source digest is `6a098384d350404d`.
The original handoff is preserved with this explicit correction. This clarification
does not create missing BT/framework findings or authorize an implicit retry; their
Rust loops still need an explicit continuation and before/after review.

Local before/after configs, artifacts, triage, tool/source/binary hashes and exact
commands remain under the respective task's `quality/` directory. The pinned tool
sources are RQLens `d28f3d9` and qmlqualitylens `97feb1f`. Worker reports preserve
early failed attempts separately from passing final checks.

## Evidence boundaries retained

- NM native terminal loss is locally suppressed through a fixture observer; its
  services are in-process. It is not OS-process crash or a dropped OS socket write.
- Clipboard private child SIGKILL and Qt recording-transport tests are complementary,
  not a combined real-Quickshell crash journey. The hidden-paste kill case must beat
  the existing 600 ms delay and assert no fake input; it is not an exhaustive timing
  proof or a rollback guarantee. The other receipt holds are explicit pre-send gates.
- Bar's fake battery starts do not exercise the production authorization/helper
  start path. The service-result limit is 16 MiB, distinct from 32 MiB event framing.
  The stalled case's 100 ms writer timeout is fixture-only. These synthetic typed
  payloads do not establish every legitimate maximum domain effect or native UI limit.
- Application's exact +1 result case is a read-only query, not an oversized effect
  receipt/timing proof. Frozen unit-service sizing and near-limit actual-process
  delivery are distinct; the latter deliberately retains 64 KiB headroom for
  independently sampled metadata. No large-record Qt/Quickshell pass is claimed.
- All child processes/fake work remain bounded and private. No production backend,
  live bus/compositor, hardware effect, real clipboard publication or deployment
  was exercised. No test was deleted or newly skipped to obtain passing checks.

## Coordinator matching checks

All checks below passed through the shared `check.sh` lock, private HOME/XDG,
unavailable host endpoints, matching sibling-source capture/preflight and bounded
timeouts. Rust/Cargo 1.95.0; Qt 6.11.1; native Quickshell 0.3.0. No preflight bypass.

| Matching check | Result |
| --- | --- |
| NM debug all targets | 102 library passes; four explicit-only probes normally ignored. Native shared-session/renewal and quiet-connect-terminal subcases explicitly pass. |
| Clipboard debug all targets | 57 library + six integration passes; two heavy cases normally ignored. Both new process tests/all eight phases pass three further serial repeats. |
| Bar debug all targets | 223 library + 29 update-worker + one native integration passes, with existing explicit-only cases excluded normally. Exact service-result and event/stalled-reader cases explicitly pass. |
| App debug all targets | 46 library + 17 session passes, including the existing private SIGKILL case affected by bus reuse. Live/systemd and explicit-only cases remain ignored normally. Exact-result, all four payload cases and strengthened bridge case explicitly pass. |
| Strict checks | All four producers: formatting and all-target/all-feature Clippy. Frontend: QML lint, generated-contract negatives/parity, NM offline contract, build-input alignment and surface catalog. |
| Actual Qt | **455 passed, zero failed, one existing renderer skip**, both development and matched Nix runs. |
| Sibling-source Nix | `nmDaemonContract`, `barDaemonContract`, `clipDaemonContract`, `appDaemonContract`, `qmlTests`, `buildInputs` pass. Late app addition was included in final Qt/build-input checks. |
| Release producer suites in Nix | NM 102 library; bar 228 library + 30 update-worker + two native integration; clipboard 59 library + six integration; app 46 library + 17 session. Existing deliberate skips remain where configured; no blanket app `--include-ignored`. |
| Source/document review | Producer index trees exactly match reviewed quality heads; frontend worker code/evidence blobs match. Frozen audit covers nine helper inventories/178 named functions and 15 tickets. Final links/fences/whitespace and scoped diffs pass. |

Local artifacts:
`/home/laufan/Projects/shelllist-orchestration/20261026T142325Z/integration-review/`.
`checks-result.json`, `nix-result.json` and `app-result.json` contain commands,
working directories, deadlines, exits and log paths. Reproduction drivers are
`check-producer.sh`, `check-frontend.sh`, `check-app.sh`, `run-checks.py`,
`run-nix-checks.py` and `run-app-checks.py`. Logs retain binary hashes and Nix
sibling/store-source maps; `reviewed-source-identities.json` seals reviewed trees
and frontend blobs. `helper-provisioning-review.md` records the provenance correction.
Final coordinator edits after executable checks are documentation only, separately
checked; they do not change the tested runtime or fixture code. Release correctness
and private process durations are not performance measurements or rollout acceptance.

## Remaining work

BT pairing/scan/OBEX and NM full-status/statistics/other operations/private prompts
remain explicit recovery work; the connect implementation does not close them.
Shared harness adapters and its blocked Lens loop remain unintegrated. Bluetooth
needs its Rust loop, global fixture regeneration and matching integration checks.
Clipboard package smoke still needs its stale interface reference (`BUS + "1"`
versus `org.laufan.ClipDaemon2`) and private activation environment reviewed.
Packaged startup/readiness, combined native crash, broader retained-client
payload parity, upgrade/rollback and serial matched-release load/memory measurements
remain separate. No code-review commit constitutes rollout approval.
