# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables or freeze visual choices unnecessarily.

## Retained coverage

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG plugins and timezone data. Both QML
runner scripts use the same offscreen/software, UTC setup. Refresh an existing
development shell after changing `flake.nix`.

- `tst_field_interaction.qml`: local drafts, binding survival after save/discard,
  backend updates during editing, native arrows, forward/reverse Tab after
  availability changes or removal, editable-only traversal, switch safety,
  pointer transactions, continuous-preview rollback and command menus.
- `tst_chooser_keyboard.qml`, `tst_chooser_memory.qml` and
  `tst_domain_workflows.qml`: search/result navigation, asynchronous restoration,
  newer-navigation/closure fences, keyed viewport and per-result memory,
  value-free selection restoration, missing/sensitive targets,
  application acknowledgement, modal containment and scoped compositor commands.
- `tst_chooser_geometry.qml`: live expansion/filter/resize anchoring and keyboard
  overflow revelation. Runtime smoke also exercises native offscreen floating
  windows; `tst_work_area.qml` covers authoritative geometry and failure recovery.
- Shared action/control tests retain keyboard, pointer and assistive activation,
  busy/disabled guards, immediate slider feedback, segmented navigation,
  native masking/reveal, read-only editing, dropdown acknowledgement/cancellation,
  command availability and close-time action-model reordering.
- Bluetooth, Clipboard, Displays, Battery, Notifications and Wi-Fi suites retain
  domain acknowledgement, failed-save drafts, retries, stale identities/replies,
  leases, secret clearing, preview/revert tokens and destructive-operation guards.
  System choosers retain explicit media targeting, capability guards,
  acknowledged mute/pin/mode settings and native tray-menu lifetime.
- Daemon/session and model suites retain protocol/generation boundaries,
  cancellation ownership, request churn, stable identities, queued-update
  cancellation and progressive/native list updates. Notification tests exercise
  live reply focus through a 205-record burst.
- JavaScript checks retain unsafe-layout rejection, numeric validation,
  resource availability versus measured zero, history/cursor failures, request
  identity, no-replay rules, battery safety and notification identity handling.
  Material contrast is checked in 150 seed/mode combinations; native QML checks
  foreground binding types and actual SVG decoding.

Expected negative-test application error logs are distinct from QML engine
warnings and remain allowed. Offscreen tests do not replace live compositor,
hardware, IME or screen-reader acceptance.

## Latest pruning checkpoint — 2026-10-05

Baseline: the incoming working tree, **including the uncommitted Lens refactor**.
Nearest-integer 67% target: **359 → 241** inventory units
(**32.87% removed; 67.13% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 118 | 79 |
| Executed QML behavioral cases, including data rows | 226 | 147 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **359** | **241** |

This is the established mixed inventory, **not independent scenarios or a
coverage percentage**. The counter now includes `portal-launcher/` and Tokio
unit tests and excludes build artifacts; the same correction counts both snapshots.
QML totals **302 → 213** include **76 → 66** excluded lifecycle hooks. Runner
and skip rules are unchanged. No assertions were hidden in uncounted helpers.
Five suites were deleted; Lens only drops their entrypoints, not thresholds or
exclusions.

Validation: 147 QML behavioral cases, all 16 behavioral JavaScript scripts,
source-tree relative imports, strict lint, runtime smoke, TypeScript typechecking,
eight Rust tests and both Python tests pass. All five daemon contract declarations
remain unchanged; the full sibling-aware Nix gate was **not rerun**. Generated
TypeScript verification fails on the incoming `BarOsdPresentation.js` drift, also
reproduced in the archived baseline; pruning does not change production code.

Direct visual, animation, wrapper, size-matrix and some consumer-specific
restoration coverage is deliberately reduced. Shared contracts do not replace
all deleted scenarios. See the [review](../docs/reviews/test-pruning-2026-10-05.md)
for decisions, explicit gaps, per-suite counts and reproduction commands.
Evidence is in ignored `target/test-pruning-current/`.

This checkpoint is not a permanent test-count cap. Add focused behavioral
regressions when a meaningful failure is found.

## Historical checkpoints

- [2026-10-04: 396 → 265](../docs/reviews/test-pruning-2026-10-04.md)
- [2026-09-27: 298 → 200](../docs/reviews/test-pruning-2026-09-27.md)
- [2026-09-26: 357 → 239](../docs/reviews/test-pruning-2026-09-26.md)

These describe earlier sources and validation, not the current suite. Always
count matching source snapshots and QML logs; the inventory script rejects
incomplete, failing, skipped or duplicate-case logs.
