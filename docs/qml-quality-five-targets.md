# Five-target quality follow-up

Baseline: `3b2d9cd` (the preceding completed refactor, checkpointed separately).
Each numbered target is a separate commit. Lens is pinned to local `6868f2f`;
matched static records and execution logs live in `target/quality-five/stepN/`.
Production metrics include generated sources, exclude tests/dev, and include all
extracted helpers. Expanded clone scans retain the preceding 200000/1000/10000
limits. Native evidence is separate; incomplete profiling is not a quality pass.

## 1 — Battery timeline translation

`BatteryFlow` separates endpoint-to-delay translation from wire-duration validation,
availability, no-op detection and immutable policy publication. Never preserves the
other duration; finite pairs retain the hibernate endpoint. Selected battery/AC
profile ownership and atomic writes are unchanged. One shared duration predicate
also serves ordinary policy edits. Availability is checked once for changed positive
hibernate durations; unchanged unavailable endpoints still reject as no-ops.

`editSleepTimeline` cyclomatic/cognitive/effort **27/32/124 → 19/18/76**.
Production totals: cyclomatic **8603 → 8604**, cognitive **6078 → 6073**, weighted
function effort **42386 → 42376**, source lines **41584 → 41582**. Extraction adds
one aggregate cyclomatic point; locality/leverage and clones are unchanged.

Validation: **44,064** original/refactored differential cases, source immutability,
new total-endpoint/wire-bound and no-op assertions, existing battery-control JS,
strict lint, and native BatteryPresentation **9 passed / 0 failed / 0 skipped**.
The native suite retains actual deferred keys, Never/lid semantics, separate
profiles, unavailable hibernation, atomic pairs and explicit failed-save retry.
No interaction or daemon safety contract is changed.

## 2 — Generator-owned shared protocol validation

Framework commit **`8084fcd`** adds opt-in `--runtime-module` and `--runtime`
generation; default output stays standalone. Shelllist generates one
`Shelllist.Io.ProtocolValidation` runtime and both App/Bar clients forward their
existing APIs to it. Module imports work from original source directories and
packaged module paths. Contracts, first-error strings and validation behavior
remain daemon-generated. The runtime and consumers are checked together by the
regeneration script and the Nix protocol-binding check.

Production source **41582 → 41534**, cyclomatic **8604 → 8537**, cognitive
**6073 → 5969**, weighted function effort **42376 → 42034**. Complete normalized
clone groups **107 → 106**, covered lines **1614 → 1484**. These figures include
the new shared runtime, not just the shortened consumers. The sibling generator
itself grows to expose/test the opt-in API; this is not a cross-repository LOC win.

Validation: two generator Rust tests, warning-fatal Clippy, exact regeneration,
all 18 JavaScript scripts, strict QML lint, runtime smoke and full native Qt
**396/0/1** (existing renderer skip). A native regression exercises both clients'
module imports, independent schemas and shared local-reference validation. An
initial test used an unmodeled sleep method; it was corrected to the existing
generated `audio.adjust` contract, not by weakening validation.

The attempted current-source Nix protocol-binding check is **blocked**, not
passed: `clip-daemon/docs/quality-refactor-followup.md` is unrelated and untracked.
It was not modified or staged. Regeneration used the explicit installed
`SHELLLIST_NM_DAEMON` override for the read-only registry command because the
sibling debug binary was absent; all five outputs compare exactly.
