# Next five QML quality improvements — 2026-11-05

Baseline: `93c7894c`, clean worktree. Ranking uses the latest complete authored
function metrics plus consumer reach, ownership risk and existing Qt owners.
The local QMLQualityLens evaluator/configuration and native Qt environment remain
fixed. Reports/logs live in ignored `target/quality-next-five-20261105/`.

## Ranked scope

1. Agenda detail admission: highest authored cognitive hotspot; validation belongs
   beside document/cache watermarks, with selection/action intent kept local.
2. Shared delta ordering: distinguish valid frames, duplicates, continuation and
   new-owner/exhaustion baselines without weakening gap/recovery fences.
3. Clipboard operations: separate receipt admission from bounded retention;
   preserve running entries, uncertainty, identity and no-replay behavior.
4. Socket replies: make correlation, eligibility and disposition explicit while
   preserving uncertain credit and late cleanup-only acknowledgements.
5. Shared chooser restoration: separate saved-list projection from native focus
   dispatch, preserving readiness, invocation and user-interruption authority.

No generated protocol, quality policy, discovery rule or skip policy is changed.
Existing meaningful Qt journeys are extended; no per-helper test suite is added.

## 1. Agenda detail admission — closed

`AgendaRepository.validDetailResult` now owns full-document identity, captured
revision, repository revision and catalog watermark admission. The controller
retains the visible-summary fence, selected-item publication and captured action
intent. A newer inspector response is still inspection, never implicit completion.
The ordinary inspector journey now rejects a newer document from an obsolete
catalog and then accepts the current catalog without submitting a mutation.

Validation: Agenda **63 passes**, strict changed-file lint and whitespace checks
pass. The initial ad-hoc lint command omitted `-I "$PWD/qml"`; the corrected
source-import context passed and is the recorded lint result. `receiveItem` cognitive/cyclomatic/weighted effort **27/25/106 → 21/19/85**.
The new repository predicate is **6/7/27** and remains in aggregate measurements:
this is an ownership/locality improvement, not removal of all validation decisions.
Authored function cognitive sum is unchanged; cyclomatic/effort rise by 1/6 at
this step. Test volume grows nine lines for the catalog-order regression, with no
new registered case. Domain safety and acknowledgement semantics are retained.

## 2. Shared delta ordering — closed

Frame validation and continuation/baseline ordering are separate predicates;
`accept` owns duplicate/recovery gates and publication. An existing recovery
journey now rejects a replacement owner's continuation before accepting its
baseline, retaining the old watermark and one gap notification throughout.

Validation: DeltaCursor **14 passes**, real Wi-Fi stream consumer **6 passes**,
strict changed-file lint and whitespace checks pass. `accept` cognitive /
cyclomatic / weighted effort **23/24/104 → 9/10/48**. Both predicates remain
measured (**9/10/38**, **7/8/31**). Whole-cursor function sums rise slightly:
cyclomatic +4, cognitive +2, effort +13. The gain is explicit state-policy phases
and a much smaller mutation entrypoint, not fewer protocol decisions. Two test
lines extend an existing case; registration count is unchanged.

## 3. Clipboard operation admission/retention — closed

`retainOperation` builds one unpublished map, trims completed entries without
removing running work or the admitted record, then publishes once. Admission
keeps metadata, action, ownership, epoch and monotonic-revision guards. Replacing
the computed-key patch object removes one temporary object per accepted receipt;
uncertain native work and terminal/no-replay behavior are unchanged.

The existing owned-status journey additionally rejects duplicate and foreign-epoch
progress without consuming its watermark or releasing its running guard.
Validation: stream recovery **14 passes**, native controller recovery **24 passes**,
strict changed-file lint and whitespace checks pass. Admission cognitive /
cyclomatic / effort **22/21/98 → 16/17/75**; retention is **6/5/27**, included in
aggregates. Combined cognitive is unchanged, cyclomatic +1 and effort +4. Four
assertion/setup lines extend an existing journey; no new registered case.

## 4–5

Pending implementation; each item is committed only after its focused checks.
