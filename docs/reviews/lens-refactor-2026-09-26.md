# Lens-guided presentation and controller refactor

Baseline: Shelllist `c96cf0a`; analyzer: QML Quality Lens `010a3c5`.
This is a bounded refactor of measured hotspots, not a rewrite of daemon policy.

## Changes

- Display validation shares numeric-range checks and delegates mode bounds to
  `parseMode`, which already enforces them. Snapping shares one coordinate
  algorithm, preserving candidate order, exclusive thresholds and first-edge
  tie-breaking. Concise pure callbacks replace unnecessary callback scaffolding;
  the redundant copy after `filter` is removed.
- Battery automation and capability descriptions use explicit message tables,
  retaining availability, lock, Keep awake and diagnostic precedence. Table
  lookup rejects inherited keys rather than interpreting them as daemon tokens.
- Six controls share an internal `InteractiveBehavior`. Theme timing, easing and
  reduced-motion policy have one implementation; slider dragging still bypasses
  animation. The component is not added to the public UI module API.
- Screenshot result text and expiry live beside the capture operation, replacing
  three controller callback/timer pairs. Writable scalar aliases retain existing
  controller reset behavior. Starting another capture cancels the preceding
  result's expiry so it cannot erase an in-flight message. The existing status
  signal remains compatible with provider controllers.
- Removed unused `BatteryContent.policy`, `ActionArea.hovered` and its now-unused
  pointer ID, and the uninstantiated clipboard `detailsFactory` test component.
  Legitimate dynamic daemon payloads and circular-owner adapter boundaries remain
  unchanged; no casts, lint suppressions or ignored signals were added.

## Comparable measurements

Both snapshots use the same project configuration, thresholds, optional parser
installation and source discovery, with external tools disabled for the static
comparison. Production excludes `tests/` but retains generated sources unchanged.
Function effort is Lens's heuristic, not measured development time.

| Production metric | Before | After |
| --- | ---: | ---: |
| Cyclomatic complexity, sum | 6,530 | 6,501 |
| Cognitive complexity, sum | 5,148 | 5,044 |
| Function effort, sum | 30,866 | 30,579 |
| Component effort, sum | 40,297 | 40,233 |
| Mean component locality | 75.27 | 75.48 |
| Mean component leverage | 52.72 | 52.91 |
| Normalized-line clone groups | 156 | 149 |
| Distinct clone-covered lines | 2,277 | 2,194 |
| Source lines | 31,318 | 31,232 |
| Physical lines | 34,312 | 34,228 |
| `property var` declarations | 419 | 418 |

Clone counts use identical expanded budgets (200,000 keys, 1,000 windows per key,
10,000 groups), giving complete normalized-line coverage in both snapshots. The
ordinary capped report remains partial; these are not structural-clone counts.

Including QML tests, analyzed source lines fall 37,449 → 37,417. Tracked source
physical lines (`qml/js/ts/mjs/py/sh/nix/rs`, including tests outside Lens roots)
fall 46,672 → 46,663 despite the added regression coverage. Markdown is excluded.
The rounded Lens score changes 85 → 86; it remains supplementary evidence.

| Function | Cyclomatic | Cognitive | Effort |
| --- | ---: | ---: | ---: |
| Display `validate` | 33 → 18 | 67 → 35 | 204 → 114 |
| Display `snap` | 11 → 5 | 25 → 6 | 94 → 34 |
| Battery `automationStatus` | 12 → 5 | 28 → 5 | 91 → 28 |
| Battery `suspendCapabilityDescription` | 18 → 12 | 40 → 16 | 128 → 66 |

The production sums include the newly extracted helpers. Shared screenshot code
appropriately gains effort and loses some locality; the owning controllers lose
coupling. BatteryController remains a substantial hotspot, not a solved problem.

## Validation and preservation

- Qt 6.11.1: strict native lint and **225 Qt test passes**, no failures/skips or
  QML engine warnings. New cases cover screenshot expiry/retry and slider motion.
- Nine Nix checks pass: `qmlLint`, `qmlTests`, `displayModel`,
  `batteryPresentation`, `batteryAutoSave`, `daemonBoundary`, `flowPolicies`,
  `typescript`, and `packagedImports` (all with `--no-write-lock-file`).
- Real Quickshell shared-UI smoke passes offscreen with software rendering.
- 41,768 deterministic before/after comparisons pass for display validation,
  geometry, snapping, fingerprints/topology and battery status precedence.
  Committed Node tests additionally cover numeric boundaries, snap thresholds
  and ties, unknown/prototype tokens, and capability-message precedence.
- Incoming edits to `tst_displays.qml` and `tst_notification_actions.qml` are
  byte-preserved and excluded from the refactor commit. Generated JavaScript and
  Nix lockfiles are unchanged. Only changed authored QML/JS was Qt-formatted.
- No live compositor, hardware or daemon deployment was tested.

Detailed local evidence and reproducible snapshot/differential scripts are in
`qmlqualitylens/target/shelllist-refactor-20260926/` in the adjacent Lens checkout.
