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

## 3. Clipboard captured edits and recovery

`draftSnapshot` owns the target/revision, preview, submitted text and direct-edit
projection shared by commit capture and failed-draft storage. `pendingCommit`
keeps that edit separate from paste intent; a failed draft never inherits a paste
session. `commitTargetChanged` is the single captured-target predicate for success
and failure after view replacement. Retirement still happens before either path
publishes. Successful displaced commits clear the captured failed draft and
refresh; uncertain displaced commits retain it without altering the new preview.

The native paste handshake has its own guarded `finishNativePaste` boundary,
separate from acknowledging a saved edit. Missing/failed/mismatched outcomes and
reopened sessions cannot replay writes or hide a different invocation. A Paste
intent arriving after submission still waits for acknowledgement, then targets
the replacement entry with the existing separate action. Mutable view flags and
captured commit metadata deliberately retain different lifetimes: `clear()` must
not erase the in-flight snapshot, and cancellation is not backend rollback.
No new automatic retry, changed request DTO, lease or revision policy.

Five added native cases cover success/uncertainty after actual result-key
navigation, missing/mismatched native paste outcomes, and a Paste intent arriving
after write submission. Existing fresh-lease/conflict, explicit save/discard,
disconnect/no-replay and hidden-session tests remain. The initial new navigation
fixture omitted `favorite`; it was corrected rather than suppressing its warning.
Final focused suite is warning-free. Full Qt: **606 passes, zero failures, one
existing renderer skip**; strict lint, 17 JavaScript checks, native smoke and
panel-UI drift review pass. Full-suite logs retain existing Time/Weather fixture
warnings and intentional negative-path diagnostics; no warning-free-host claim.

Relative to step 2: production LOC **44,840 → 44,834**, cyclomatic **8,020 → 8,019**,
cognitive **5,506 → 5,497**, function effort **39,767 → 39,744**, component effort
**45,670 → 45,651**. `applyEditCommit` cyclomatic/cognitive **19/26 → 10/12**;
`failEditCommit` **7/6 → 4/3**. These aggregate comparisons include all new helpers
(snapshot **1/0**, target predicate **3/2**, native handshake **7/6**), not just
smaller headline methods. Locality, leverage and complete clone groups are unchanged.

Across all three commits: production cognition **5,508 → 5,497**, function effort
**39,752 → 39,744**, component effort **45,654 → 45,651**, but LOC rises by **17**
and cyclomatic sum by **2**. This is a bounded ownership/readability improvement,
not a claim of broad architectural leverage or fewer domain decisions. Fourteen
focused regressions bring the established inventory to **555**; the earlier
pruning target remains a historical checkpoint, not a cap on useful tests.

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
