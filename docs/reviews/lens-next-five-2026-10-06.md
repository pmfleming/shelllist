# Five follow-up quality improvements — 2026-10-06

Baseline: `099c723` (the preceding measured cleanup). Lens revision and scope
match [the previous review](lens-refactor-2026-10-06.md). Local static snapshots
are `target/lens-refactor-current/series-before-*` and `step1-*` through `step5-*`.
Production excludes tests/dev; generated JavaScript is counted once by Lens,
while TypeScript is edited as its source of truth. No analyzer settings or
suppressions are changed. Each improvement is validated and committed separately.

Selected work: authoritative IP diagnostics, explicit portal response phases,
shared chooser lifecycle guards, application window-row locality, and safe
application-operation ownership/bounded feedback. These target observed hotspots
and real failure boundaries rather than unrelated normalized option-table clones.

## 1. IP diagnostics share the authoritative raw-buffer decision

`FieldValidation` now consumes its existing validation state when producing
messages, rather than parsing the same address/prefix again. The standalone
`issue` API delegates invalid-only diagnostics after validating the raw input.
A full editor buffer containing an otherwise valid address/prefix followed by
whitespace previously returned no diagnostic after trimming, despite being
correctly rejected by the authoritative validator. It now reports the buffer
error. Translation stays in QML, syntax policy stays in TypeScript, and save/Tab
still retains a domain draft without submitting invalid settings.

Validation: the new JavaScript regression fails against the frozen baseline;
**106 JavaScript checks**, **7 native IP-field Qt passes** and strict QML lint
pass. Native tests cover full address and prefix buffers, silent editing,
error-on-save, traversal, correction/discard and the backend readiness guard.
Logs: `/tmp/quality-ip-before.txt`, `/tmp/quality-step1-{qt,lint}.txt`.

Production delta: source lines **0**, cyclomatic **−2**, cognitive **−5**,
function effort **−14**, component effort **−8**. Test coverage grows separately.

## 2. Portal response phases are explicit and fail closed

The portal adapter now accepts only nonempty owned response IDs in its three
response-bearing phases. An empty/unowned failure could previously reset an
executing intent and prevent its eventual completion acknowledgement. Prepare
returns after claiming; only the remaining claim path may execute. Immutable
claim identity is checked with one explicit field list, and expiry must be finite
and in the future. Typed QML method signatures replace the adapter's untyped
parameters/returns; protocol payloads remain dynamic records.

Validation: **17 portal Qt passes**, including changed launch ID/episode/URL,
expired/non-finite claims, duplicate and unowned responses during execution,
completion acknowledgement, transport recovery and actual Alt+I navigation.
Strict QML lint and daemon-boundary checks pass. Logs:
`/tmp/quality-step2-{qt,lint}.txt`.

Incremental production delta: source lines **+1**, cyclomatic **−5**, cognitive
**−8**, function effort **−21**, component effort **−14**. Safety checks were
strengthened, not removed to lower the branch count.
