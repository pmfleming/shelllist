# Material 3 plan gap review — 2026-10-05

## Verdict and scope

**The shared Material foundation is largely delivered. The remaining actionable gaps are keyboard/accessibility reachability, rendered focus/icon contrast, and incomplete migration of custom cards—not another wholesale component redesign.**

Reviewed HEAD `77f3834` plus the existing working-tree changes. This is a source review with three fresh offscreen Qt reproductions and palette/compositing calculations, **not a fresh screenshot review or live desktop acceptance**. No production code, service, or existing user edits were changed.

Authority, in order:

- [Current interaction contract](../chooser-keyboard-workflow.md) for navigation and field transactions.
- [Standard surface action row](../proposals/surface-action-row.md) for primary/secondary commands.
- [Accepted Material plan](../proposals/material-expressive.md), [visual foundation](../material-visual-foundation.md), and [delivered roadmap slices](../material-roadmap-implementation.md).
- The [October 1 visual recommendations](material-recommendations-2026-10-01.html) are proposals except where subsequently accepted/delivered. They are not ten outstanding mandatory requirements.

Do not reinstate Right-to-edit, per-result expansion, immediate deferred-setting writes, action-button Tab stops, hover tooltips, or the superseded two-row header. The September audit is historical; its major fixes are recorded in [the follow-up](material-surface-follow-up.md).

## Findings, in priority order

### 1. P1 — Battery history's explicit inspection is unreachable through panel keyboard navigation

**Evidence:** `battery/BatteryHistoryGraph.qml:38–69`, `qml/Shelllist/Ui/DetailsNavigation.qml:193–215,234–238,269–277`, `qml/Shelllist/Ui/PanelSurface.qml:69–73`.

The graph still implements native Enter/Right inspection and Left/Right sample movement, but `activeFocusOnTab` no longer makes it reachable: the panel intercepts Tab, and shared navigation discovers only registered editors and scrolling pages. The graph is neither an editor nor an `ActionControl`, so it also has no content-command route.

A fresh actual `BatteryContent` probe cycled Tab twelve times. Focus alternated between the overview's available ordinary controls, never the graph; the graph was absent from both navigation targets and commands. Giving the graph native focus explicitly and pressing Enter did start inspection. Its inspection implementation works; keyboard entry is missing.

**Impact:** removing hover values has left precise historical time/charge/power inspection pointer-dependent, contrary to the explicit-information and keyboard-first requirements.

**Next:** expose an explicit inspection command through shared command navigation, with a supported inspection boundary and focus restoration. Do not make every read-only chart a field Tab stop or introduce another panel-local editing model. Test entry without `forceActiveFocus()`, sample movement, Escape, and return to the prior field.

### 2. P2 — Destructive icons break the semantic foreground/background pair in dark mode

**Evidence:** `qml/Shelllist/Ui/DestructiveIconButton.qml:5–7`; consumers include `launcher/ApplicationListRow.qml:41`, `launcher/ApplicationInstanceList.qml:85`, and `clipboard/ClipboardListRow.qml:63`.

The shared destructive button uses `Theme.danger` but hardcodes its highlighted icon to white. The actual focused dark-mode control resolves to **white on `#ffb4ab`**, approximately **1.70:1**. Its intended `Theme.dangerText` is `#690005`, approximately **7.72:1** against that background. The white icon fails even the plan's 3:1 meaningful-control target.

**Next:** use the paired danger foreground and check hover, focus and pressed composites in both themes. This affects common Close/Delete affordances, not just a development gallery.

### 3. P2 — Browse focus is immediate, but not contrast-qualified

**Evidence:** `qml/Shelllist/Ui/FocusRing.qml:15–16`, `qml/Shelllist/Ui/ResultRow.qml:59–62`, `tests/check-material-colors.js:24–27`.

Browse focus adds only an **8% primary tint**, with no edge. A selected result retains the same selection fill/avatar when focus moves elsewhere, so the tint is its principal added keyboard-focus cue.

Using the shipped generator with seed `#6750a4`, the composited tint versus the unmodified selected-row background is **1.11:1 light / 1.17:1 dark**. Over Surface Container High, it is **1.11:1 / 1.20:1**. These calculations do not meet the accepted plan's 3:1 distinguishable-focus target. Editing's accent edge is a separate state and does not fix browsing.

The existing palette check passes because it compares **opaque primary** against surfaces, not the actual low-alpha focus paint. This is a rendered-state coverage gap, not a failure of Material Color Utilities.

**Next:** agree and test a distinguishable, immediate tonal browse treatment, including selected results and controls. Preserve the current control-only highlight boundary; do not silently restore the rejected heavy rectangular focus ring. Validate actual layered colors rather than only raw palette roles.

### 4. P2 — Inline tray buttons announce an action that assistive activation does not perform

**Evidence:** `bar/BarTrayItem.qml:13–14,28–35,47–55`.

The item declares `Accessible.Button` and a name, but has no `Accessible.onPressAction` handler. Pointer clicks alone reach `routeClick()`.

A fresh Qt probe invoked `Accessible.pressAction()` and observed **zero** tray activations; calling the pointer routing function for a left click produced **one** activation. The dedicated Tray chooser remains a keyboard alternative, but does not make this exposed bar button operational for assistive technology.

**Next:** wire the accessible primary action to the existing guarded routing, preserving menu-only item behavior. Verify both ordinary and menu-only items. This does not require introducing keyboard focus traversal into the bar.

### 5. P3 — Custom resource/history cards still bypass opaque tonal containment

**Evidence:**

- `battery/BatteryHistoryCard.qml:28`: Surface Container High at 70% alpha.
- `launcher/ApplicationResourceLaneChart.qml:36`: the same 70% alpha fill.
- `launcher/ApplicationResourceMetadata.qml:18`: 72% alpha fill.
- In contrast, `qml/Shelllist/Ui/DetailCard.qml:22–24` uses opaque Surface Container Low.

Roadmap item 5 is delivered at the shared-card boundary, but these custom containers retain older translucent styling. This is a consistency/migration gap; no text contrast failure is established here. Resource-series transparency and weather artwork are different concerns and should not be globally removed.

**Next:** migrate the outer card fills to deliberate opaque semantic tiers without replacing their charts, changing telemetry, or flattening useful hierarchy.

## Roadmap and element coverage

| Element / plan area | Current assessment | Remaining work |
| --- | --- | --- |
| Palette, dedicated fonts/icons | Delivered: Material Color Utilities, desktop seed/light-dark, Roboto Flex, Material Symbols with specialist fallback | Fix semantic-pair bypasses; verify actual rendered states |
| Buttons, switches, sliders, fields, segmented controls | Shared Material-derived controls and field transactions exist | Live pointer/IME/accessibility and large-text acceptance; do not replace desktop dimensions mechanically with mobile tokens |
| Search — item 2 | Delivered 56px pill, native editor and embedded actions | Counts intentionally remain in footers; not an implementation omission |
| Results — item 3 | Delivered 64px segmented rows, 40px leading containers and selected-only detail chevron | Focus contrast; extra Enter-action glyph was not part of the delivered contract |
| Focus — item 4 | Selection, browsing and editing states exist; feedback is immediate | Finding 3. The mockup's inset outline is not automatically approved |
| Tonal cards/settings — item 5 | Shared cards, spacing tokens and always-visible sections delivered | Finding 5; always-visible information intentionally supersedes older disclosure recommendations |
| Shortcut hints — item 8 | Delivered modifier-held hints with letter commands | Real AltGr/window-manager interaction acceptance |
| Header hierarchy — item 7 | Superseded by delivered labelled primary + compact secondary responsive action row | Do not rebuild the mockup's connected two-row toolbar |
| Typography — item 1 | Dedicated font delivered; full role-scale recommendation not implemented | `Theme.qml:108–118` still has 11px caption, 13px body, 22px display and seven size tokens. `GroupCountBadge.qml:19` still uses literal 9px text. A role/legibility pass remains a design decision, not an established requirement to implement all fifteen roles |
| Detail tabs — item 6 | Bottom-positioned, icon-only tabs remain consistent with accepted presentation | Persistent labelled navigation-bar treatment needs approval; accessibility names are not visual labels |
| Geometry — item 9 | Anchored two-pane layout and bounded overflow delivered | `PopoverGeometry.qml:15–18` retains 453px list / up-to-1040px preferred split, not the proposed large/extra-large canvases. Treat wider size classes as an optional follow-up |
| Bar — item 10 | Continuous eight-group pictorial bar, numerical clock, separate Audio/Media/Tray routes delivered | Finding 4 and prototype acceptance. Widened workspace pills/group containers/new clock typography remain suggestions, not accepted omissions |
| Dialogs | Shared scrolling body, accessible dialog title/description, contained native traversal delivered | Actual screen-reader/IME and constrained-size acceptance, not the old clipping finding |

### Domain status

- **Battery/Power:** prioritize chart keyboard entry and custom card containment. The old profile-selector and truncated safety-warning findings should not be repeated as current defects.
- **Applications/Clipboard:** prioritize destructive-icon contrast; Applications also has custom resource-card migration. Existing editor drafts, retry and resource content should remain intact.
- **Displays:** current settings/category/arrangement work supersedes the old long-form audit snapshot. Preserve local drafts, explicit Preview and Keep/Revert; no new display defect is established by this review.
- **Notifications:** current inspector/selected-message command architecture differs from the old hover-action row. Do not report the September invisible-action reproduction as if it were current. Live toast interaction/accessibility still needs acceptance.
- **Wi-Fi/Bluetooth:** shared fields, prompts and acknowledgement are the baseline; no new domain-specific Material defect is established here. Technical sections being always visible is now intentional.
- **Activity/Time & Weather:** the prior naming/hero fixes are recorded as delivered. Large-text chart/forecast and small supporting-type review remain acceptance work.
- **Audio/Media/Tray:** acknowledged volume steps, now-playing hierarchy, supplied tray icons and dedicated routes exist. Do not invent an absolute-volume setter or device-routing capability as a styling fix.

## Validation and limits

- Temporary reproduction: `target/material-gap-review/tst_review.qml`.
- Run: `tests/run-qmlquality-tests.sh -input target/material-gap-review/tst_review.qml -o -,txt` in the cached local Qt 6.11.1 development environment.
- **Three behavioral probes / five passes including hooks. These assert existing defects, not fixes.** Log: `/tmp/shelllist-material-gap-review.log`.
- Tray fixture emitted `ReferenceError: Status is not defined` from the test SystemTray boundary's missing enum. No suppression was added; the activation counters and source handler omission are independent of that urgency-decoration binding. This is not a warning-free production smoke claim.
- Fresh `node tests/check-material-colors.js qml/Shelllist/Ui/MaterialColors.generated.js`: all **150 seed/mode combinations pass**. The additional contrast figures above use standard sRGB relative luminance and alpha compositing with the same generator.
- The full native suite, strict lint and sibling gate were **not** rerun. No new screenshot, screen-reader, compositor, hardware IME, scaling or GPU/performance acceptance is claimed.

Recommended sequence: restore chart keyboard entry → repair destructive icon pairing and tray assistive activation → resolve browse-focus contrast → finish custom containment → obtain decisions on the remaining typography/tab/size-class/bar mockups. Full acceptance remains open even where implementation gates pass.
