# Remaining work branches — coordinator integration

2026-10-27: **accepted for the bounded scopes below**, after implementation,
matching checks, implementation commits and a separate coordinator quality pass.
Frontend implementation is `60678b2`; clipboard quality refactor is `c943625`.
The commit containing this final record is the separate frontend quality/evidence
commit. Partial implementation/analysis remains partial; this is not rollout approval.
Bridge remains default, with five independent socket opt-ins. No service restart,
deployment, user-domain effect or push occurred during this integration.

## Inventory and source review

All 36 non-main branches across the eight project repositories were inventoried.
Ten older feature/architecture branches are already ancestors of main. The 26
orchestration branches are covered by earlier integration records, this checkpoint,
or the superseding Bluetooth repair. Older unsafe Bluetooth heads are not merged
back over their repair. Worker histories, raw partial/failing handoffs and original
negative witnesses remain intact; coordinator commits aggregate reviewed source,
not a claim that every worker commit is now in main's ancestry.

| Checkpoint | Reviewed producer / frontend worker heads | Main producer integration |
| --- | --- | --- |
| Bluetooth authority repair | `9dce998` / `1fc9eb3` | `8fe2f64` |
| Wi-Fi status observations | `b5c2218` / `466df41` | `4b84f64` |
| Clipboard package safety | `ee8d5a8` / `942aa6d` | `1777c03` |
| Bar semantic facts | `261e626` / `01c291e` | `31189af` |

Full original-baseline inventories, including seeds, tests, generated companions
and quality evidence, were reviewed: respectively 13+16, 14+12, 4+2 and 10+17
producer/frontend paths. Actual Git heads, not inconsistent reported NM clean-head
labels, identify the reviewed sources. All selected worker blobs matched the staged
integration. Producer trees matched exactly before the coordinator's clipboard
flake addition; frontend additions from earlier accepted work were preserved.

Two coordinator-owned implementation additions were tested:

- The obsolete Bluetooth stream test now requires operation/scan terminals and an
  unrelated prompt cancellation to preserve the current prompt and draft. Only
  cancellation carrying that prompt's own ID retires it before the next test case.
  This strengthens the safety contract rather than restoring unsafe draft closure.
- `clip-daemon/flake.nix` adds `checks.x86_64-linux.packageSmoke` (and the matching
  supported-system check): isolated inert activation tests plus static inspection
  of the real rendered package. It never executes that package's main or engine.

## Bounded dispositions

- **Bluetooth:** local acknowledged operation IDs alone confer reconciliation and
  cancellation authority. Aggregate rows and live peer events cannot adopt another
  consumer's operation. Live/recovered terminals do not close a same-device prompt;
  prompt-ID/request-window authority is independent. Admission/cancellation and
  store-before-deliver terminal evidence remain; cancellation is not rollback.
  Broader pairing/scan/OBEX lifecycle, unknown/tombstone retirement and production
  crash/load qualification remain open. The canonical offline protocol-to-daemon
  fixture edge remains the explicitly reviewed architecture-policy debt, not a
  rule pass or permission for constructors/effects in that edge.
- **Networking:** only `wifi.status` gains serialized authoritative observations,
  invalidation-generation/owner fences, atomic payload/publication and ordered
  unavailable state. Unchanged observations retain identity. Consumer recovery
  preserves accepted work, prompts and drafts; it does not scan, reconnect, submit
  credentials or revive earlier scan intentions. Connectivity/inventory and other
  unfinished streams are not silently accepted.
- **Clipboard:** current `ClipDaemon2`, explicit wiring-only mode, private synthetic
  activation, unique-owner reads and no activation fallback are integrated. This
  is not packaged-main/engine, effective-session startup or rollback acceptance.
- **Bar:** native finite-percent presentation and an advertised, supported next
  manual profile target replace frontend policy guesses. Each explicit command
  captures one target and native code revalidates before persistence/hold release.
  Geometry, editing transactions and hardware safety remain. CQ-10 upstream
  acquisition validity is unfinished; these presentation facts do not complete it.

## Matching combined checks

Fourteen serialized steps passed under the run's shared `check.sh` lock, private
HOME/XDG, unavailable host endpoints, offscreen/software Qt and two build workers.
All eight repository HEAD/index/worktree tuples were fenced around every step.
Matching sibling-source capture/preflight and development shells were used.

- **522 Qt passes, zero failures, one existing renderer skip**, in development and
  matching Nix; full QML lint, TypeScript/generated contracts, surface/build-input
  checks, Bluetooth fixture negatives and producer/consumer fixture parity pass.
- Bluetooth: 83 library + two process tests, strict Clippy/formatting; the private
  shared-owner native authority/draft probe passes twice with zero active and one
  retained operation, no replay or orphan.
- NM: 111 library passes, strict Clippy/formatting and the explicit private native
  socket/status probe. Child-process test output is not counted twice.
- Bar: 226 library + 29 update-worker + one native integration pass in development,
  strict Clippy/formatting, and explicit private Quickshell acceptance. Matching
  Nix runs 231 library + 30 update-worker + two native integration tests.
- Application's existing near-limit private Quickshell acceptance passes again
  against the combined frontend; this is not an exact-ceiling or effect-receipt
  qualification.
- Clipboard: 21 private Python tests in development and Nix, Python compilation,
  Nix parsing, static real-package wiring. Matching package runs 59 library + six
  integration tests; real packaged-main/engine/rollback remains explicitly NOT RUN.
- Nix gates: `btDaemonContract`, `nmDaemonContract`, `barDaemonContract`,
  `clipDaemonContract`, `qmlTests`, `buildInputs`, and clipboard `packageSmoke`.

Attempt 1 ended without a completion receipt during Bluetooth Clippy; its cause
was not established. Its passed frontend/ordinary BT tests and incomplete log are
preserved, not converted into a pass. After an empty process census and unchanged
source seal, an explicit fresh attempt reran all fourteen gates successfully.
Correctness durations are not performance measurements.

## Completed quality review and retained limits

The original worker Rust/QML BEFORE/AFTER loops and separate nonempty quality
commits remain the full-baseline evidence. Extraction is partial where declared;
Python, TypeScript, shell and Nix checks are not Lens certifications. No thresholds,
exclusions, analyzer sources, binaries, versions or dependency locks were changed.

Coordinator review found and repaired a further Python harness lifetime issue:
cleanup could signal a process-group ID after its leader was already reaped.
The safe BEFORE witness used inert children with every group signal mocked. Normal
completion and external reaping both requested signals after reaping. Two new
regression cases fail against the exact archived implementation helper (three
assertions including Popen/raw-waitpid subcases), without actual PID reuse or any
foreign-process signal.

The separate quality refactor retains the leader through non-reaping `waitid`
observations and signals before final wait, preserves one deadline after EOF,
rejects externally reaped identities and makes cleanup idempotent. AFTER observes
an unreaped leader during normal cleanup and no signal requests after external
reaping. This is owned-group cleanup for inspected non-detaching tools/fixtures,
not generic containment. No activation retry or domain effects were added.

Affected checks pass: Python 3.13.13 syntax; **23 private Python tests, zero skips**
in development and matching Nix `packageSmoke`; Nix parsing and real-package static
wiring. The package rebuild passes 59 Rust library + six integration tests. Full
Qt and QML lint pass again: **522 / zero failures / one existing renderer skip**.
Real packaged-main/engine/rollback remains explicitly NOT RUN. Executable source
seals matched after checks; only documentation was subsequently added.

The coordinator Bluetooth test correction received five fresh QML Lens producers
BEFORE and AFTER with identical source/evaluator fingerprints, analysis rules,
findings, metrics and rule coverage. The source hash is `053a8d2b…`, across 38 files,
374 functions and 1,040 bindings. QML Lens 0.5.0 / Node 24.16.0 reports 212 findings;
the semantic subset has 60 findings (four medium, 56 low), 27 unresolved imports,
78 unresolved types and 548 skipped evaluations. This remains **partial**.

The corrected test's 30-line advisory is explicitly retained: cyclomatic 1,
cognitive 0, one cohesive sequence proving prompt identity across operations,
wrong-ID cancellation, matching-ID cancellation and stale observation. Splitting
those ordered assertions only to avoid a length warning would obscure the safety
witness. The unresolved `Shelllist.Io` static-model warning is not suppressed;
actual matching Qt/lint checks supply separate execution/import evidence. No QML
refactor is justified. Rust executable bytes remain identical to the reviewed
worker trees, so their full-baseline Rust Lens loops remain applicable; this
coordinator pass adds no Rust code or claim of complete macro/identity extraction.

Python/Nix are unsupported by those Lenses: manual lifecycle review, actual Python
syntax/tests, Nix parsing/build and explicit limits are the evidence, not a fake
Lens pass. The isolated Nix check needs no further refactor after its real-package
and negative fixture tests. Pinned analyzer source, CLI/dist and lock hashes were
reverified; no analyzer, dependency lock, rule, threshold or exclusion changed.

Evidence root:
`/home/laufan/Projects/shelllist-orchestration/20261026T232107Z/integration-review/remaining/`.
It retains `branch-inventory.json`, `review-inputs.json`, full/code-only patches,
source-equivalence records, `attempt-1/`, `attempt-2/`, exact drivers and pinned tool
provenance. Earlier framework/application acceptance remains in the
[Wave 1 record](wave-one-integration-review.md). Remaining lifecycle/schema/
conversion work, startup decisions, packaged rollback, mixed load/fairness/memory
and exclusive serial matched-release qualification stay in the
[completion plan](../contracts/project-completion-plan.md).
