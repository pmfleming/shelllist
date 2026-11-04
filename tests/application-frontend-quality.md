# W1-APP frontend quality review

2026-10-26. Quality continuation of `27c41a1`, original baseline `6f14ede`.
**Partial static evidence**, not integration or rollout approval. See the scoped
[implementation record](application-frontend-acceptance.md) for CQ-15/native routing
behavior, retained initial failures and the deferred serial release recipe.

## Full scope and static policy

Inventoried the complete original-baseline diff, including AppApi aliases,
ApplicationLifecycle/Operations/Presentation, native entrypoint, existing Qt action
suite and implementation evidence. No inherited seeds or generator changes.
Pinned qmlqualitylens `97feb1f714c680ffcceedc935ecaa974d0c52cb1`, Node 24.16.0,
measures all changed QML/JS plus unchanged launcher/test context using fixed owned
`quality/qml-static.json`. Source roots include both native/Qt fixture files.

Project defaults enable profiling/runtime/test adapters and stale report imports;
they were inspected, not run. The owned static config disables all execution
adapters, imports no runtime/coverage/benchmark reports and uses no suppressions,
exclusions or threshold changes. Focused producers: hotspots, clones, QML health,
semantic rules and correctness catalog; no measure-all or audit campaign.

## Triage and refactor

BEFORE: 25 QML components with syntax-backed complexity, six clone groups, 16
health/semantic findings. One finding is introduced by the implementation:
`acceptPayload` in the native entrypoint lacked parameter/return annotations.
It now explicitly accepts **var envelope, string error** and returns **void**,
matching Io.DaemonBackend's actual response signal. Unknown/malformed envelope
values remain var and retain the same protocol, identity, length and full-content
checks. No signal/guard/state ownership or output-validation fallback changed.

AFTER: **15 findings** (11 pre-existing untyped test helpers, three API-surface and
one binding-pressure advisory); six clone groups unchanged. Retained findings are
unchanged baseline helpers, launcher resource/controller/window composition, not
authorization for unrelated cleanup. Origin attribution is manual full-baseline
Git diff/source inspection, not an independently measured original-baseline run.
The native max cyclomatic/cognitive **16/16** and QML high-risk count five remain;
full UTF-16 validation and reentrant-safe progress/peer gates are intentionally
explicit. No mechanical splitting, Rust port of UI state or guard deletion.

The 14 Close/CloseWindow vectors remain in one existing Qt suite: destructive
outcome/recovery distinctions, foreign/late receipts and explicit retry materially
protect the assigned contract. Static catalogs cannot prove value or replace the
native producer/actual Qt boundaries; no unique tests, cases or skips were removed.
The bounded Rust helper lifetime fix and its private timeout/reap regression are
recorded in `app-daemon/contracts/native-frontend-quality.md`.

## Retained limitations

QML syntax and requested clone/complexity scans completed without recovery,
approximate metrics or omitted clone groups. Overall confidence stays **partial**:
**24 unresolved imports + 48 unresolved types**, **443 skipped semantic evaluations**,
and no configured native .qmltypes. Off-scope shared Io/Core/UI are read-only
fingerprinted context, not a certified Qt/C++ implementation/type hierarchy.
Static correctness catalog has execution not configured; actual test results below
are independent bounded runs and never promote missing static evidence to green.
Rust's unchanged unexpanded declare_methods macro likewise keeps Rust envelopes
partial. No compiler expansion, coverage or runtime analysis campaign was run.

## Affected checks and provenance

All passed through check.sh with private HOME/XDG/unavailable host endpoints,
matching family sibling capture/preflight and bounded children:
- Full Qt development and sibling Nix: **469 passed / zero failed / one existing
  renderer skip**. Existing malformed-event diagnostics remain.
- Strict full QML lint plus explicit native entrypoint lint; generated contracts;
  source/build-input and surface checks.
- Three actual Quickshell native repeats, each ordinary + near-limit UTF-8 modes,
  with full **16,707,950-byte** comments, generated request/event validation and
  healthy logical/native peers. No payload rendering/logging or fake launch.
- Producer formatting, strict all-target/all-feature Clippy, ordinary 46 library +
  18 session passes, explicit exact-result/+1 and four payload regressions.
- Sibling Nix buildInputs/appDaemonContract/qmlTests; release app 46 library + 18
  session passes. No blanket ignored/live-manager tests.

Before/after configs, artifacts, triage, exact drivers/logs and final clean-head
capture live at
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/06-application-frontend/quality/`.
Main producer commands:
`check.sh timeout 1800 bash quality/measure-static.sh before` and
`check.sh timeout 1800 bash quality/check-affected.sh` (latter also saves AFTER),
using absolute task script paths in actual invocation. Final static extraction
uses the unchanged measure-static script/config at both clean quality heads.

Pinned QML CLI SHA-256:
`b6443d1f0b8a610f73c79926080245e718f53ebaa0d903639bfb44df497b2a85`.
Rust CLI SHA-256:
`622b2c793a574781cd40a190a457f58af4b8c222ee5efce04c4e77488c50929a`.
Pinned locked rust_facts/ast_hasher helper compilation into task-private cache was
performed as authorized; tools/main CLIs/locks remain unchanged. Task-local shell
and Python control drivers are outside both lenses: bash -n, py_compile and actual
private executions supply their explicit language-specific checks.

Bridge/defaults, external D-Bus/retained clients and all native action/target/
operation/revision/uncertainty/no-handoff/explicit-retry guards remain unchanged.
No whole-panel maximum rendering, peak-memory/latency benchmark, packaged startup,
combined frontend/process crash, effect-receipt-loss or rollout claim. Separate
coordinator disposition and compatible integration are still required.

## 2026-11-04 project review and receipt refactor

Baseline `3f737d39423415df54ff1696719fc107b1c465b8`, including the incoming
`bar-controls.json` fixture edit, which is preserved. Ran the local QMLQualityLens
0.5.0 checkout (`97feb1f714c680ffcceedc935ecaa974d0c52cb1`) using Node 24.18.0
and the unchanged project configuration. Both captures have evaluator fingerprint
`ecbe448644080d95c83fc67b09fdf409d983163a2b5166d7b7eeb2585c605655`;
configuration SHA-256 is
`64404e44991983d30f01fcf36c99f2f3c4e5380ec9ad31af2b3312d10a5d3ef1`.
No roots, exclusions, suppressions, thresholds, generated APIs or dependencies changed.

### Review decisions

The scan covers 537 files, including 460 QML components and 60 JavaScript files.
Reviewed the leading transport, cursor, notification, chooser and application
owners against their actual consumers and Qt tests:

- `JsonlSocketTransport.receive` remains the leading handwritten cognitive
  hotspot (32, cyclomatic 31). Its correlation, admission, uncertain-credit and
  late-cleanup guards require a separate transport-focused change; extracting
  branches solely to lower its reported maximum would not simplify that policy.
- `NotificationCatalog.acceptApps` (24/23) mixes bounded staging, exact-app
  lookup and publication. A future change must retain atomic replacement,
  revision fencing and bounded scanning through `tst_notification_cache.qml`.
- Application receipts repeated the same identity policy in generic transition
  wrappers and a separate unknown-outcome path. `operationStage` now derives
  identity from the retained record, checks it once, and returns only the stage
  used by the owner. Three redundant helpers, duplicate identity evaluation and
  unused transition-object fields are removed. `expectedRevision` uses the
  equivalent native safe-integer predicate.
- `tst_daemon_sessions.qml` retained an unused recursive paging mock and a copied
  client/lifecycle fixture. It now reuses `DaemonTestCase` with two actual
  `DaemonBackend` consumers, checking attachment, shared session identity, peer
  destruction and surviving-consumer reconnect. There is no new fixture API.
- The 14-row Close Cartesian product is replaced by seven representative rows.
  Both canonical actions retain success/identity coverage; the separate native
  row-focus journey retains still-open observations. Three overlapping recovery
  tests become one admission → malformed/foreign read → reordered observation →
  quiet-terminal recovery journey. No unique outcome category is retired.

### Comparable measurements

Production scope below is exactly `ApplicationLifecycle.js` and
`ApplicationOperations.qml`; test scope is exactly `tst_application_actions.qml`
and `tst_daemon_sessions.qml`. Complexity/effort totals sum Lens function records;
weighted function effort is advisory, not Halstead effort or developer time.

| Measure | Before | After |
| --- | ---: | ---: |
| Selected production cognitive total | 138 | 128 |
| Selected production cyclomatic total | 159 | 145 |
| Selected production weighted function effort | 733 | 670 |
| Selected production physical lines | 340 | 310 |
| Selected test physical lines | 577 | 495 |
| Selected test source lines | 552 | 474 |
| Project Lens source lines | 58,672 | 58,564 |
| Project function cognitive / cyclomatic totals | 8,516 / 12,372 | 8,505 / 12,348 |
| Project weighted function effort | 59,553 | 59,443 |
| Session test locality score | 84 | 96 |
| Shared DaemonTestCase observed consumers | 47 | 48 |

`ApplicationOperations.apply` itself moves from cognitive/cyclomatic 20/21 to
17/17, weighted effort 95 to 82. `expectedRevision` token Halstead effort moves
from 1507.27 to 245.93; `apply` has incomplete Halstead evidence because of its
nested callback, so no paired Halstead claim is made there. The consolidated
`operationStage` is still a review finding (17/17); the longer combined recovery
journey is also flagged. These findings remain visible and unsuppressed.

All rounded project scores remain unchanged: overall 82, locality 76, leverage
31, duplication 96. Production locality/reuse scores remain unchanged. Reusing
the fixture adds one test dependency (session-test fan-out 2 to 3), while removing
local client policy and reducing its referenced-ID coupling. The fixture's reuse
score was already capped at 100. Global clone detection remains partial at its
100-group limit; removal of the copied fixture is source-reviewed, not a claim
that whole-project clone count improved. No reachability-only export suggestion
was treated as proof of dead production code.

A separate fixed physical-code census counts 622 tracked regular files with
`.qml`, `.js`, `.ts`, `.rs`, `.py`, `.sh` or `.nix` suffixes, including generated,
test and tool code, without following symlinks: **80,861 → 80,749 lines (-112)**.
Documentation and JSON fixtures are outside that code count.

### Coverage evidence and reproduction

The lost-admission journey now rejects foreign operation IDs, targets and native
actions, and zero, fractional and string revisions before accepting a valid
unknown outcome. Two deliberate faults, separately removing target and action
matching, pass the previous version of that retained case and fail its revised
version. Both mutations are restored. This is bounded fault-detection evidence
for that journey, not a whole-suite mutation score or a numeric coverage gain.
A bounded JavaScript comparison also checks 1,747 captured-identity/stage and
revision-predicate combinations against the baseline implementation; native Qt
tests remain the behavior owner.

Reproduce static measurements with:

```sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js analyze --config qmlqualitylens.config.json --format summary
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure quality.locality_leverage --config qmlqualitylens.config.json
```

Native checks use the existing `.direnv/flake-profile-*.rc` environment, Qt 6.11.1,
and the repository's offscreen/software/UTC runner. Raw before/after reports,
comparison, fixture sources, equivalence/fault-check scripts and logs are retained
under ignored `target/quality-review-20261104/`.

Full baseline Qt: **719 passed, zero failed, one existing skip**. Full final Qt:
**710 passed, zero failed, the same existing skip**. Counts include lifecycle
hooks; the nine removed behavioral invocations are seven duplicate Close matrix
rows and two merged recovery cases. No tests are excluded or newly skipped.
The retained skip is `MediaChip::test_artworkReallyClipsRoundedCorners`, which
requires an RHI renderer rather than the runner's software backend. Focused
Actions passes 22 checks; session attachment passes three (both include hooks).
Strict full QML lint, generated contract checks, source-tree relative import
checks and `git diff --check` pass.
The panel UI review reports zero changed-line and zero new-wrapper prompts.
There are no visual-role or keyboard changes. No numeric statement/branch
coverage, hardware mutation, deployment, sibling rebuild or release-performance
claim is made.
