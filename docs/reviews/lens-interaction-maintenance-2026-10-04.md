# Interaction-layer QML maintenance

## Baseline and scope

Reviewed Shelllist with the local `../qmlqualitylens` checkout, version 0.5.0 at
`345ea8658035ff26b93707153e30924ea6faf568`, using Qt 6.11.1. Baseline source:
`8331047331bcefc8b1eb4b0a6db9f300a1bec8ed`, including the user's existing,
unchanged `flake.nix` edit. Lens configuration was unchanged on both sides:
SHA256 `b5c8d9780dc0f44ccae0354776648b1deda24be60ece972d7ea627e265254aa4`.

The complete configured source tree was measured. This is a bounded refactor of
shared interaction infrastructure, not a rewrite of domain controllers. Generated
Material color code was not hand-edited to lower its large effort score.

## Findings and changes

- **Duplicated command-menu machinery.** Header overflow and content commands
  had separate popup, focus-return, traversal, disabled-item and activation code.
  Internal `ActionMenu.qml` now owns that behavior; the former internal
  `DetailsCommandMenu.qml` is removed. Owners retain action models, presentation
  adapters and effects. Native command objects are not mapped into fresh DTOs:
  changing availability must not reset the selected command. Activation captures
  the action before closing because focus restoration can reorder the model.
- **Repeated field dispatch and key handling.** `FieldEditSession.handleKey`
  handles native multiline/dropdown transaction keys once, including popup input.
  Shift+Enter stays a native newline. Read-only/capability checks live in each
  session's `available` binding beside its control. `DetailsNavigation` uses its
  existing typed session resolver instead of maintaining another full type list.
- **Navigation hotspots.** Presentation restoration and applying native focus
  have separate responsibilities. Selection snapshots/restoration reuse typed
  `FocusLocations` helpers. Forward/reverse Tab rotates an ordered candidate list
  captured before save, then rechecks availability after save. It still handles
  disabled, hidden and removed fields without losing the saved field's position.
  Available fields are read synchronously, not cached in another reactive list:
  `onTargetsChanged` can run before such a binding updates during Loader teardown.
- **Obsolete migration/dead paths.** Removed `keyboardWorkflow` and its true-only
  call-site settings, the unreachable details branch after `cycleRegion`'s early
  return, and the unused header-inclusive target-discovery mode. Native required-
  input dialogs retain their separate modal behavior. Removed Lens's two unused
  IDs (`backButton`, `secondaryRepeater`) and an unused shortcut-delegate index.
- **QObject escape hatches.** Action rows/buttons use typed lists; the attached
  Keys object and shortcut delegates use QObject/control types. Heterogeneous
  action models, JSON DTOs and field values remain genuinely dynamic. No duck-
  typed editor interface, blanket suppression or weakened threshold was added.

The mandatory [interaction contract](../chooser-keyboard-workflow.md) remains in
force. Source-binding preservation, live-preview rollback, field-only traversal,
command modality and asynchronous focus restoration retain their regressions.
Daemon acknowledgement, validation, retry, leases and effect routing were not
combined into a generic state machine.

## Measurements

Same analyzer/configuration/source discovery on both sides. Production excludes
`tests/` and `dev/`; all includes them. Component counts stay **286 / 343**.
These are structural heuristics, not measured runtime performance improvements.

| Metric | Production before | Production after | All before | All after |
| --- | ---: | ---: | ---: | ---: |
| Cyclomatic complexity | 7,101 | 7,073 | 7,835 | 7,808 |
| Cognitive complexity | 4,718 | 4,675 | 5,041 | 4,998 |
| Function effort | 35,880 | 35,725 | 42,912 | 42,780 |
| Component effort | 40,597 | 40,425 | 51,730 | 51,580 |
| Mean locality | 75.9336 | 75.9545 | 76.5656 | 76.5860 |
| Mean leverage | 36.9231 | 36.9755 | 32.4052 | 32.4490 |
| Source LOC | 37,244 | 37,175 | 47,185 | 47,142 |
| Physical LOC | 41,672 | 41,608 | 51,952 | 51,914 |
| Normalized clone groups | 130 | 129 | 177 | 176 |
| Clone-covered lines | 1,882 | 1,866 | 2,601 | 2,585 |
| `var` properties | 438 | 433 | 469 | 464 |
| `ignoreUnknownSignals` | 0 | 0 | 0 | 0 |
| Lint disables | 15 | 15 | 15 | 15 |

Total tracked physical code, including canonical/generated sources and tests but
excluding documentation and ignored analysis artifacts: **57,372 → 57,334**,
net **38 lines removed**, including the additional regressions. This includes the
new `ActionMenu.qml`, not just the tracked-file diff's apparent deletion savings.
Cleanup's unused-ID candidates fall **2 → 0**; no unused component/export
candidates are reported. That is not proof that every public member is used.

Complete normalized clone scans use limits of 200,000 keys, 1,000 windows per key,
10,000 groups, with **zero omitted windows/groups** in both scopes on both sides.
The default capped audit is not used for the clone totals above.

The gains are modest, and individual trade-offs remain visible:

- `restoreLocation` cognitive complexity **28 → 11**, plus **9** in the new
  `restoreFocus`; combined effort **117 → 95**, not merely a moved hotspot.
- `cycleFocus` cognitive complexity **16 → 8**, effort **72 → 48**.
- `SurfaceActionRow` effort **348 → 242**, locality **0 → 12**.
- `DetailsNavigation` effort **1,057 → 1,006**, but locality **40 → 35**.
- `FieldEditSession` effort increases **114 → 159** as it takes responsibility
  for shared editor keys; `FocusLocations` increases **143 → 152**.
- `DropDownList` locality **45 → 44**, despite effort **235 → 197**.

Global heuristic score remains **83**. Native-tool review findings fall
**760 → 755** and architecture high-risk nodes **29 → 28**. Neither unchanged
scores nor improved aggregates certify correctness.

## Validation and remaining limits

- Full Qt suite: **374 passes**, zero failures/skips; baseline **373 passes**.
  Existing tests were retained. Added content-menu wrap/availability coverage,
  Shift+Enter checks, and action identity across close-time model reordering.
- Strict native lint passes. Lens's separate native lint covers **397/397**
  QML/JavaScript inputs with zero diagnostics.
- Fresh Lens execution independently records **374 passes**. Both parser oracles
  pass on **343** QML files without findings. Its runtime-smoke adapter passes.
- Packaged-relative-import check, generated TypeScript check and
  `git diff --check` pass. `flake.nix` was checked against its original diff.

Lens's verdict remains **incomplete**, for the same reasons at baseline:

1. Required side-effect-in-binding analysis cannot resolve **197** targets with
   dynamic access/assignment or unknown call targets.
2. `qmlformat` exits 1 without output for the existing tray mock
   `tests/qml/imports/Quickshell/Services/SystemTray/SystemTrayItem.qml`.
   Formatting drift stays **97** files; neither issue is suppressed.

No full sibling/Nix build, matched live performance comparison, compositor,
hardware, IME or accessibility acceptance is claimed. Nothing was deployed or
restarted; the refactor is left uncommitted for review.

## Local reproduction

Ignored evidence is under `target/lens-interaction-maintenance/`: `before` and
`after` summaries, detailed records, exhaustive clone scans, and `before-tools/`
and `after-tools/` native artifacts. The local snapshot script uses the same
analyzer/configuration for both sides, excluding execution evidence from the
structural comparison. It includes new source files and excludes deleted ones.

```sh
node target/lens-interaction-maintenance/snapshot.mjs after
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
tests/run-qml-tests.sh
tests/run-qmllint.sh
node tests/check-packaged-imports.js .
node tools/build-typescript.mjs --check
```

## Further review priorities

`ChooserSession.apply`, `BatteryController`, and Clipboard/Bluetooth recovery
remain substantial hotspots. Any later extraction should follow cohesive state
ownership and add lifecycle regressions, not split files for scores alone.
Normalized clones also group unrelated option arrays with different semantics;
those were not forced into one abstraction. Export/member cleanup remains
incomplete where Lens cannot resolve dynamic consumers.
