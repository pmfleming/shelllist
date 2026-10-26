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
