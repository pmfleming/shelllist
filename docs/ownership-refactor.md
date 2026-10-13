# Ownership-focused quality improvements

Baseline: `7cdd1d4` plus five incoming edits, preserved separately from these
commits. Local Lens revision: `6868f2f`. Source snapshot, incoming hashes, static
configs, native logs and production summaries: `target/ownership-refactor/`.

## 1. Notification completion boundary

`NotificationBackend.finish` now owns only consume-once request identity,
generation fencing and queued-event ordering. `acknowledge` handles the already
admitted domain completion. Scoped catalog, app-policy and deletion paths still
return before generic action/error/snapshot handling. No new callbacks, context
schema, state owner or generic dispatch framework was introduced.

The distinction is an ownership improvement, **not an aggregate complexity win**.
An initial boolean-returning scoped-dispatch helper was rejected because it added
another routing decision. The retained two-phase version keeps every original
branch and its order. Lens measures `finish` cyclomatic/cognitive **23/26 → 3/2**;
`acknowledge` is **21/24**, so combined cognitive complexity is unchanged and
cyclomatic sum increases by one function base.

Production before → after: LOC **44,817 → 44,824**, cyclomatic **8,017 → 8,018**,
cognitive **5,508 → 5,508**, function effort **39,752 → 39,758**, component effort
**45,654 → 45,659**. Mean locality **75.7429**, leverage **38.2445** and complete
clone groups **106** are unchanged. The added boundary/comments cost seven lines;
no complexity reduction is claimed by moving branches between functions.

Native `NotificationActionContract` adds queued-event-before-acknowledgement,
duplicate-versus-newer-request, obsolete-generation consent, and cancellation
publication-isolation regressions (three cases). Existing request DTO, reply
draft, malformed confirmation, policy, timeout, reconnect and no-replay suites stay.
Full Qt: **595 passes, zero failures, one existing renderer skip**. Strict lint,
17 JavaScript checks and native runtime smoke pass. No tests were removed.

## 2. Chooser restoration decision versus effects

`ChooserSession.restorationRegion` classifies the saved region against current
context and detail availability, without effects or another stored request.
`apply` retains invocation admission, presentation synchronization, list/viewport
restoration, readiness and the `restoring` reentrancy guard, then executes the
chosen region explicitly. List-control availability is still checked at focus
time. All cancellation handlers, two-turn readiness deferral and generation-fenced
modal fallback are unchanged. No panel-local navigation or new key model.

Six native cases cover changed result, closed details, removed selection,
available/unavailable list controls, and readiness-gated editor resumption that
cannot restore a discarded field value. Existing deferred-loader/new-navigation,
closure, capability and sensitive-field tests remain. Full Qt: **601 passes,
zero failures, one existing renderer skip**; strict lint, 17 JavaScript checks,
runtime smoke and panel-UI drift review pass.

Relative to step 1, production LOC **44,824 → 44,840**, cyclomatic **8,018 → 8,020**,
cognitive **5,508 → 5,506**, function effort **39,758 → 39,767**, component effort
**45,659 → 45,670**. `apply` cyclomatic/cognitive **19/26 → 15/19**, plus the new
decision function **6/5**. Aggregate cognition improves by two, but explicit
classification/switch effects add lines and effort; this is not a broad metric
win. Locality, leverage and complete clone groups remain unchanged.

## Evidence limits

Metrics are advisory production-only projections, excluding `tests/` and `dev/`
from the unchanged configured discovery, not correctness or branch coverage.
Complete clone comparisons use 200,000 keys, 1,000 windows/key and 10,000 groups;
zero omitted windows/groups are required. Default capped clone scans and semantic
abstentions retain their limits. Static configs disable tool execution/imported
reports; independent native passes do not make static evidence complete.

No suppression, discovery, threshold, generated source, build check or runner
changes. No full sibling-aware package/Nix build, hardware, RHI, IME or human
screen-reader acceptance is claimed. The existing portal Rust lockfile mismatch
is outside this work. The five incoming edits are not included in these commits.
