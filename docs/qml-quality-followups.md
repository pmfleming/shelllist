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
