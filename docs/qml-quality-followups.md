# Four-pass quality follow-up

Baseline: clean `051f462`. Each pass is validated and committed separately.
Local evidence lives in ignored `target/quality-passes/`. Qt totals include hooks;
the existing RHI-only artwork skip is not passing coverage. No source/test
exclusions, skips, thresholds or suppressions are added.

## 1 — Restore the resource-pixel baseline

The failure at `tst_application_resources.qml:376` was a test-environment defect,
not a plot defect. `fc-match 'Material Symbols Rounded'` returned Noto Sans in the
development environment. A captured render showed literal `developer_board` text
from the Memory card spilling into Activity at the failing pixel (671, 146).
Using the application's packaged Fontconfig file made the unchanged pixel
assertion pass. There was no reason to alter chart gaps or relax the pixel test.

`flake.nix` now shares one font configuration across the application, gallery,
Nix Qt check and development shell. The test explicitly diagnoses missing Material
Symbols; it does not skip. Refresh existing shells with `nix develop`.

Validation: actual `nix develop --no-write-lock-file -c tests/run-qml-tests.sh`
passes **366/0/1**; strict QML lint passes. No production QML behavior or keyboard
contract changes. Native font setup fixes the previously recorded baseline failure.
Nix evaluated local inputs without writing the lock; this is not a full sibling
release build or hardware/IME/accessibility acceptance.

## 2 — Timeline response ownership and atomic windows

`NotificationTimeline` separates ownership, continuation consistency and
publication. One nullable staged window replaces independently mutable staged
rows/metadata. An owned reply consumes staging once; only a validated continuation
can install it again. Failure, stale cursor, midnight change, duplicate entries
and hiding discard the whole unpublished window. Unowned replies cannot clear
staging or busy state. Duplicate-key collection no longer repeatedly copies its
accumulated array. No mutation/retry policy or field interaction changes.

Local Lens 0.5.0, unchanged static scope/tools-disabled configuration:
`receive` cyclomatic/cognitive/weighted effort **30/30/123 → 14/13/60**.
Whole-file function sums are **108/87/402 → 111/87/416**: extraction adds function
baselines and does not eliminate necessary guards. This is a state-ownership and
peak-complexity improvement, not an aggregate complexity/LOC reduction. One fewer
`property var` represents unpublished state. Expanded clone groups stay 157.
Lens remains advisory/incomplete; no Halstead or developer-time claim is made.

Ten new native cases cover each ownership coordinate and rejection while staging;
existing viewport, keyboard, deletion and malformed-wire tests remain. Full Qt:
**376/0/1**. Strict lint and notification-presentation JavaScript checks pass.
A trial use of `Array.flatMap` failed on QV4 and was replaced by supported
`forEach` accumulation before the passing run. Logs/configs are in `pass2/`.

## 3 — Bluetooth response responsibilities

Adapter request identity, acknowledgement and post-acknowledgement observation now
live together in `BluetoothAdapterEdits`. Send failure/disconnection retire the
captured identity; duplicate/unowned completions cannot reapply observations.
Backend failures share one read-versus-mutation feedback route. The canonical
TypeScript Bluetooth presentation helper formats profile outcomes with explicit
guards, and the generated JS is rebuilt. Remove the intermediate profile-success
message so observers see only acknowledged success, partial persistence or unknown.

Backend `finish` cyclomatic/cognitive/weighted effort **25/34/142 → 8/7/45**.
Across production functions this pass also reduces sums **7,939/5,455/39,314 →
7,934/5,438/39,272**; production source LOC **39,723 → 39,720**. Mean locality,
leverage and expanded clones are unchanged. Tests/canonical TypeScript add code;
this is not a whole-repository LOC reduction.

Eight new native cases cover final-only profile messages, read/mutation send and
response errors, and acknowledged settings followed by a malformed snapshot.
Existing native save/discard, partial retry, captured-adapter and transport-loss
cases pass. Full Qt **384/0/1**; strict lint, Bluetooth JavaScript (248 checks),
TypeScript generation/typechecking, daemon boundary and relative imports pass.
Numeric-role review reports no new overrides. Evidence: `pass3/`.

## 4 — Application operation outcomes

`apply` retains request/operation/target/action ownership checks and record
construction, then dispatches active progress or terminal completion. Terminal
handling computes one warning decision for failure, launch-placement partial
success or observed Close, instead of independently recombining those conditions.
Handoff still publishes pending ownership before dismissal; no launch/close replay,
optimistic window removal or new command/field behavior is introduced.

`apply` cyclomatic/cognitive/weighted effort **29/30/133 → 9/8/41**; new
`updateActive` **5/4/23** and `complete` **13/12/58** are included in aggregate sums.
Production sums fall **7,934/5,438/39,272 → 7,932/5,432/39,261**. Production source
LOC grows **39,720 → 39,725**; locality, leverage and clone counts are unchanged.

Twelve new native cases exercise placed/unavailable receipts, terminal placement
without prior handoff (including legacy absent placement), and closed/still-open/
unknown/missing/failed/cancelled Close outcomes while browsing another application.
They assert retained window identity, no replay, no duplicate refresh/notification,
and no Close handoff even with an irrelevant receipt or placement payload.
Existing native command, status-recovery and reopened-view coverage remains.
Full Qt **396/0/1**; strict lint, application lifecycle JavaScript, TypeScript,
runtime smoke, daemon boundary and packaged imports pass. Numeric-role review
reports no added overrides; `git diff --check` passes. Evidence: `pass4/`.

## Combined result and limits

Compared with `051f462`, production function sums are **7,936/5,455/39,300 →
7,932/5,432/39,261**. Component effort **45,119 → 45,082**; production source LOC
**39,713 → 39,725**. One fewer dynamic property; no new escapes or suppressions.
This pass prioritizes coherent state ownership and smaller peak functions, not
LOC reduction. Added regressions increase test LOC. Mean locality/leverage remain
**75.66/37.95**, expanded normalized/structural clones **157/35**, score **83**,
parser diagnostics **0**, and the single enum-only tray-mock cleanup finding remains.

The former resource-pixel failure is resolved, not skipped. The only remaining Qt
skip is existing RHI-only artwork coverage. Lens still reports incomplete static
contracts due to unresolved binding side effects; metrics are advisory. No full
sibling-aware Nix release build, live hardware/compositor/visual acceptance,
profiler or coverage run is claimed.
