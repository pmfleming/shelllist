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

## 2–5

Pending implementation; each item is committed only after its focused checks.
