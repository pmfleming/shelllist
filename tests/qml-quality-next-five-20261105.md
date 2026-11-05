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

## 4. Socket reply eligibility/disposition — closed

`responseRecord` owns correlation, shutdown, written-record eligibility, late
resource restrictions and captured route/payload validation. `receive` retains
parsing, event delivery and the exact uncertain-credit/disposition ordering.
The late-resource journey now sends a foreign-route duplicate after its one late
acknowledgement: it must be ignored without delivering, granting credit or
retiring the healthy owner. Both subscription and cleanup lanes are exercised.

Validation: socket **22 passes**, cleanup **32 passes**, bridge **11 passes**,
strict changed-file lint and whitespace checks pass. Socket `receive` cognitive /
cyclomatic / effort **24/24/119 → 10/10/57**; eligibility is **15/16/71**, retained
in totals. Combined function sums rise by 1 cognitive, 2 cyclomatic and 9 effort;
the gain is a focused delivery transaction with an explicit eligibility boundary,
not a claim of fewer wire rules. Three test lines extend an existing case.

## 5. Shared chooser restoration — closed

The session passes captured presentation directly to its native owners. The list
restores selection independently of viewport permission; navigation receives an
explicit editor permission instead of a cloned location with rewritten intent.
This removes a temporary list wrapper and pending-location clone from restoration.
All shared-panel callers grant editor permission explicitly. A changed selected
key still clears queued viewport work, and clean invocations still start at top.
The existing readiness journey checks that saved editor intent survives the
browse-only phase without granting edit authority or restoring an unsaved value.

Validation: chooser memory **7 passes**, field interaction **8 passes**, chooser
keyboard **4 passes**, strict changed-file lint and whitespace checks pass. An
initial attempt to use typed default arguments failed Qt compilation; the final
API uses required typed permissions and every caller was updated. `apply`
cognitive / cyclomatic / effort **22/16/91 → 15/13/73**. Decisions in the native
owners remain counted. Four assertion/setup lines extend an existing test; one
existing direct navigation call is updated for the explicit permission. Full-suite
validation also exposed a launcher click before its asynchronous controls had
finished layout. Baseline and candidate launcher suites both pass in isolation
(26 checks each); this does not establish that the original full-suite failure
was absent on baseline. The retained mouse journey now requires the shared Qt
window's polish work to finish before clicking, preserving its backend assertion.
A render-frame wait proved unsuitable here and was replaced with `waitForPolish`;
the corrected handoff vectors pass (5 checks including lifecycle hooks).

## Combined evidence and limits

The five improvements preserve the registered suite and extend existing behavioral
journeys. In disposable archived source, each journey fails behaviorally when its
relevant guard is broken, then passes with byte-identical restored source:

| Area | Deliberate fault | Retained Qt owner |
| --- | --- | --- |
| Agenda | Remove catalog watermark fence | `test_ordinaryInspectorGetAcceptsNewerRevisionWithoutCompleting` |
| Delta | Allow replacement owner to begin with continuation | `test_chainDuplicatesGapAndAuthoritativeReplacement` |
| Clipboard | Remove operation epoch fence | `test_ownedStatusRepairsQuietTerminalLossWithoutAffectingPeersOrReplaying` |
| Socket | Allow repeated late resource receipts | `test_lateResourceReceiptsCannotReleaseUncertainNativeCredit` |
| Chooser | Ignore explicit editor permission | `test_readinessResumesFocusButNeverRestoresUnsavedValues` |

These checks establish detection of those five faults, not numeric line/branch
coverage. Fault logs and restoration logs live beside `fault-results.json` in the
ignored evidence directory; production source was never mutated for this check. A further socket-order fault
moves route validation ahead of duplicate eligibility: the added retained-byte
assertion fails when it incorrectly retires the healthy owner; restored source
passes (`fault-socket-order.log`, `restored-socket-order.log`).

Whole-tree strict lint, generated protocol checks, source-relative packaged import
resolution, IP control checks (450), panel numeric/UI advisory (zero prompts), and
both offscreen runtime smokes pass. This is source/runtime validation, not a Nix
package build or a claim about live compositor rendering. Full serial Qt result:
**731 passed, zero failures, one unchanged MediaChip renderer skip** in
`full-qt-final.log` (595 behavioral passes and 136 lifecycle hooks). The first
combined run reported 730 passes, one launcher
mouse-action failure and the existing renderer skip; it is retained as
`full-qt.log`, not counted as a passing run.

Measurement uses Node 24.16.0 and the same frozen local evaluator fingerprint
`857cd4a335adb086d1d37ba54350628048b261f17874d0b7f2867abb9399b159`.
`measure-step.mjs` records each stage against `93c7894c` with execution disabled;
real Qt/lint checks run separately. Final tracked snapshots can be compared with:

```sh
node /home/laufan/Projects/qmlqualitylens/scripts/compare-refactor.mjs \
  "$PWD" 93c7894c HEAD qmlqualitylens.config.json \
  "$PWD/target/quality-next-five-20261105/controlled-comparison"
```

Helpers remain included in authored totals (excluding `tests/`, `dev/` and generated
functions): cognitive **7655 → 7653**, cyclomatic **10754 → 10761**, weighted effort
**46907 → 46928**, functions **3645 → 3650**. Lens measured source lines **59023 → 59064**;
raw tracked physical line changes are production +24 and existing tests +23. No registered tests were added or removed.
Overall score remains **82**, locality **76**, leverage **31** and duplication **96**.
Paired archived-source binding/cohesion reports keep 455 reachable and 8 unreachable
components, 20 unresolved external types, 399 incomplete binding-graph files,
and 1006 incomplete cohesion objects. Those graph/cohesion capabilities remain
partial; they do not establish an improved architecture score.
Clone analysis remains partial/capped at 100 groups; its changed omissions cannot
establish clone reduction. No new suppression, dynamic escape hatch, generated
code or policy exception is introduced. These are bounded ownership, allocation
and entrypoint-readability gains; this batch does **not** claim lower total LOC,
aggregate effort/cyclomatic complexity, or a measured leverage/locality score gain.
