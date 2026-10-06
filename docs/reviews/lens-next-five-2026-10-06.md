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
