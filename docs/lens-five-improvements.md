# Five focused QML quality improvements

Baseline: `09fb7e8`, including the incoming Bluetooth/contract/keyboard-document
edits, which are preserved and excluded from these commits. Lens is the local
`../qmlqualitylens` at `6868f2f` (0.5.0), built with Node 24.16; Qt is 6.11.1.
Local evidence: `target/lens-refactor/`, including the incoming patch, baseline
artifacts and `snapshot.mjs`. Both snapshots use identical source discovery and
expanded normalized-clone limits (200000 keys, 1000 windows/key, 10000 groups).
Production excludes only tests/dev; full-scope figures retain them. Effort below
means Lens's weighted function heuristic, not hours or aggregate Halstead effort.
No suppressions, thresholds, test discovery or source roots are changed.

Baseline native Qt suite: **203 passed, 0 failed, 1 existing renderer skip**.

## 1. Remove retired IP editors

Lens identified `IpAddressField`, `PrefixLengthField` and `ValidatedIpField` as
unreachable. Repository and sibling QML/Nix reference searches found only their
exports and mutual implementation references; Wi-Fi already uses shared `IpField`.
Remove those controls/exports and their orphan prefix-error branch in
`FieldValidation`. Keep the active DNS list editor and complete-buffer guards.
The SystemTray Status enum finding is intentionally retained: enum-only test API
is not evidence of dead code.

Production changes: source lines **43831 → 43783**, physical lines **48702 →
48649**, cyclomatic **9395 → 9391**, cognitive **6766 → 6764**, function effort
**45813 → 45800**, clone-covered lines **1984 → 1970**. Mean leverage improves
**36.0268 → 36.2162**; mean locality falls **74.4613 → 74.2553** because the removed
small dead components were highly local. This is not an all-metric improvement.

Validation: strict QML lint; actual Wi-Fi IP field suite **8 passes**; parser
validation **106 checks**; `git diff --check`. No key, save/discard, acknowledgement
or safety behavior changes; the existing chooser keyboard contract still applies.
