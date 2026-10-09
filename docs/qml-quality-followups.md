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
