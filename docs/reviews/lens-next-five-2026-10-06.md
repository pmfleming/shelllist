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

## 3. Chooser restoration uses one invocation lifecycle guard

`ChooserSession.invocationActive` centralizes enabled/active/not-suspending checks
used by admission, remembered region, queued application and modal fallback.
Disabling session memory now cancels outstanding work immediately; re-enabling
it is not a new invocation. Previously queued `apply` could dereference a removed
memory owner, or deferred readiness could resurrect a cancelled editor. Capture
intentionally keeps its separate pre-hide semantics so suspension still saves
ordinary focus before cancellation. No key model or domain writes changed.

Validation: **13 chooser-memory Qt passes** and **17 field-interaction passes**,
plus strict lint. New native tests disable memory both before queued application
and while waiting for capabilities, remove/reinstall its owner and verify that
result focus remains without edits. Existing close/reopen, modal, source-binding,
loader readiness, viewport and new-input cancellation tests remain green.
Logs: `/tmp/quality-step3-{qt,fields,lint}.txt`.

Incremental production delta: source lines **+2**, cyclomatic **−5**, cognitive
**−6**, function effort **−18**, component effort **−9**. The shared predicate
adds one binding in place of duplicated lifecycle expressions.

## 4. Application window rows own their local presentation and commands

`ApplicationWindowRow.qml` now owns the window badge, title, acknowledged status
and scoped commands, with explicit typed application identity, controller and
measurement inputs. Only the window's actual JSON record remains dynamic. The
list owns iteration and common workspace-column measurement; it no longer embeds
a nine-level object tree or supplies incidental outer IDs to row internals.
Geometry, shared command discovery, stable IDs and per-application guards are
unchanged. This is a domain component, not a new generic row framework.

Validation: **16 application-details Qt passes**, strict lint, and **5 targeted
fractional-scale passes**. Coverage retains alignment, long titles, passive labels,
field exclusion, named menus, busy/removed-window guards and adds snapshot reorder
with a live application-name fallback and ID-based pointer dispatch. The new
pointer test waits for layout polish before hitting a reordered row.
Logs: `/tmp/quality-step4-{qt,lint,fractional}.txt`.

List source size **205 → 51**, maximum object depth **9 → 4**, locality **0 → 89**;
the extracted row has depth **6**. Complexity/function effort are unchanged.
Across production this deliberate ownership boundary costs **21 source lines**,
**17 component-effort units** and one component; mean locality improves by
**0.0456**, while mean leverage decreases by **0.0735** because the new domain
component has one consumer. These are explicit tradeoffs, not a code-size or
aggregate-leverage win.

## 5. Application status reads have one completion owner

`finishStatus` replaces separate success/failure lookups. The backend offers every
successful response to that ownership check before dispatching other payloads;
missing/null/malformed status payloads can therefore release their read instead
of wedging all subsequent Check status requests. Empty IDs, stale errors and null
operation events cannot retire another request or complete a mutation. Existing
target/action/lifecycle validation still authorizes actual transitions.

The 64-target feedback cache and its reconciliation copies use prototype-free
objects, so opaque target IDs such as `__proto__` remain ordinary owned entries.
Updating a target refreshes its cache position; eviction never removes pending
operation ownership. Construction uses Qt-supported object operations, not the
unavailable `Object.fromEntries` API.

Validation: **16 application-action Qt passes**, strict lint, application lifecycle
and application-history JavaScript checks. New native tests cover malformed reads,
subsequent recovery, stale failure fencing, null events, no mutation replay,
cache bounds/refresh/eviction, opaque keys and pending ownership after eviction.
The history test adapter now mocks the unified completion interface.
Logs: `/tmp/quality-step5-{qt,lint}.txt`.

Incremental production delta: source lines **−3**, cyclomatic **0**, cognitive
**+1**, function effort **0**, component effort **−1**. The extra empty-ID safety
guard is retained despite its branch cost.

## Combined result and final gates

| Metric | Production baseline → final | All analyzed sources baseline → final |
| --- | ---: | ---: |
| Source lines | 38,507 → 38,528 | 47,304 → 47,455 |
| Cyclomatic | 7,573 → 7,561 | 8,289 → 8,286 |
| Cognitive | 5,131 → 5,113 | 5,437 → 5,423 |
| Function effort | 37,875 → 37,822 | 44,252 → 44,310 |
| Component effort | 42,524 → 42,509 | 52,560 → 52,668 |
| Mean locality | 75.4527 → 75.4983 | 76.5641 → 76.5994 |
| Mean leverage | 36.8243 → 36.7508 | 32.6068 → 32.5568 |
| Clone groups | 113 → 113 | 152 → 152 |
| Clone-covered lines | 1,580 → 1,580 | 2,162 → 2,162 |

Tracked code lines across languages: **58,835 → 59,019**. Added safety regression
coverage and the explicit row boundary increase size; this sequence is not a
net line-count reduction. Production effort and both scopes' complexity improve;
test-inclusive effort and aggregate leverage do not. Dynamic-property and lint
suppression counts are unchanged. Expanded clone enumeration remains complete.

Final validation: **345 Qt passes, zero failures, one existing skip**; strict
lint; generated TypeScript check; 106 IP checks; daemon-boundary, application
lifecycle and history checks; both real Quickshell runtime smoke fixtures; and
`nix build .#shelllistConfig --no-link --no-write-lock-file`. No dependency lock
change. The targeted row fractional-scale checks also passed (see step 4).
Qt uses the same font configuration as the preceding review. Final logs:
`/tmp/quality-five-final-{qt,lint,smoke,nix}.txt`.

This sequence uses matched static Lens snapshots, not a new full profiler gate.
The previously documented Lens timeout/coverage/formatter limitations remain
unresolved; no full-contract or performance success is claimed. Full daemon
contract matrices, the full package build and live hardware/IME/screen-reader
acceptance remain outside these targeted changes.
