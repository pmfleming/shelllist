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
  value-free selection restoration, missing/disabled/sensitive targets,
  application acknowledgement, modal containment and scoped compositor commands.
- `tst_chooser_geometry.qml`: live and fractional expansion anchoring,
  work-area fallback, focused-delegate guards and keyboard overflow revelation.
  Runtime smoke also exercises native offscreen floating-window geometry.
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

## Latest pruning checkpoint — 2026-10-04

Baseline: the incoming working tree at `8331047`, **including the uncommitted
interaction maintenance refactor**. Nearest-integer 67% target: **396 → 265**
inventory units (**33.08% removed; 66.92% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 99 | 80 |
| Executed QML behavioral cases, including data rows | 286 | 174 |
| Rust tests | 4 | 4 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **396** | **265** |

This is the established mixed inventory, **not independent scenarios or a
coverage percentage**. `count-test-inventory.py`, runner discovery and skip rules
are unchanged. QML totals **374 → 244** include **88 → 70** lifecycle hooks,
which are excluded above. No retained tests are skipped or hidden, and assertions
were not moved into uncounted helpers. Nine QML suites were deleted; Lens's
entrypoint list only removes those files, without changing thresholds or exclusions.

Validation: 174 native behavioral cases, all 16 behavioral JavaScript scripts,
packaged-import checking, strict lint, runtime smoke, generated TypeScript checking
and both Python tests pass. Rust tests and all five daemon contract declarations
remain unchanged; the full sibling-aware Nix gate was **not rerun** for this pass.
Production sources and the incoming `flake.nix` diff are unchanged.

Direct visual, animation, wrapper, size-matrix and some consumer-specific
restoration coverage is deliberately reduced. Shared contracts do not replace
all deleted scenarios. See the [review](../docs/reviews/test-pruning-2026-10-04.md)
for decisions, explicit gaps, per-suite counts and reproduction commands.
Evidence is in ignored `target/test-pruning-20261004/`.

This checkpoint is not a permanent test-count cap. Add focused behavioral
regressions when a meaningful failure is found.

## Historical checkpoints

- [2026-09-27: 298 → 200](../docs/reviews/test-pruning-2026-09-27.md)
- [2026-09-26: 357 → 239](../docs/reviews/test-pruning-2026-09-26.md)

These describe earlier sources and validation, not the current suite. Always
count matching source snapshots and QML logs; the inventory script rejects
incomplete, failing, skipped or duplicate-case logs.
