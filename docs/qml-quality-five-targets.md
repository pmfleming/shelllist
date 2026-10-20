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
