# Display settings redesign

## Step 1 — independent global settings

- Search's trailing settings action opens global Focus without a selected or connected monitor.
- Monitor details retain Settings/Information; global presentation memory has its own key.
- Global pages do not expose layout actions or the layout-preview shortcut.
- Context switches preserve the existing details loader and per-monitor tab memory.
- Validation: strict QML lint passed; Displays Qt suite: 20 passes, zero failures (including hooks).

## Step 2 — persistent layout map

- One draft-aware map now lives between search and the scrolling monitor list, including single-output and global-settings views.
- Removed the separate Arrange editor/action and its hide button; position fields remain the keyboard equivalent.
- The map is an accessible graphic, not a browse/Tab target. Pointer selection/dragging never focuses it; Escape can cancel an active drag.
- Compact-map edits now receive the same discard protection as expanded layout edits.
- Validation: strict QML lint passed; Displays Qt suite: 21 passes, zero failures (including hooks). Pointer drag, single-screen visibility, draft consistency and compact discard protection covered.

## Step 3 — concise Material settings hierarchy

- Focus opens with three common controls and four category links, not all 26 settings.
- Pointer, Keyboard, Applications and Cursor are separate retained subpages; Back returns to Focus before collapsing details.
- Wrapping switch rows, responsive choice/value editors and tonal category lists use shared Material controls/tokens.
- Per-setting help is explicitly keyboard/pointer accessible; raw compositor keys, telemetry and restore semantics live in Diagnostics.
- Existing capability, numeric validation, acknowledgement and retry guards remain intact.
- Validation: strict QML lint passed; Displays Qt suite: 21 passes, zero failures (including hooks). Help/category navigation sends no daemon mutations. The runner reports its existing asynchronous engine-destruction diagnostic.

## Step 4 — regression matrix

- Added real-key coverage for the search gear, category navigation, numeric editing, layered Escape, contextual help, Tab traversal and return-to-search focus.
- Covered 320×360, 390×600, 1040×480 and 1040×780 canvases, non-scrolling map placement, control containment, hotplug without selection and invocation focus restoration.
- Numeric drafts survive category navigation; map and settings navigation never mutate the daemon. Existing preview/token/rollback tests remain in the suite.
- Displays: 27 passes. Pure display model checks passed.
- Concurrent shared-header edits made the live full suite fail (318 passes / 6 failures, all in shared header cases) and introduced SurfaceActionRow lint/runtime warnings. Those files were not changed here.
- Revalidated an isolated archive of `e9d5b43` plus this step's tests: strict QML lint passed; complete native suite **324 passed, zero failed**. Evidence: `/tmp/display-step4-isolated-{lint,full}.txt`.

## Step 5 — rendered acceptance and safety validation

- Added the explicit non-mutating `tests/manual/tst_display_review.qml` fixture and reproduction notes in `tests/manual/README.md`.
- Generated 28 packaged-font light/dark PNGs in `target/display-settings-review/`: compact, layout, draft, Focus, every category, Diagnostics, help, narrow list/editor, short Focus and trial confirmation.
- Inspected the renders. This caught literal icon-name fallback/overflow: registered the Material names used by the new rows and used the existing gear glyph for the identity tile. Added an icon-resolution regression assertion. The global identity colour no longer depends on the selected monitor's enabled state.
- The healthy Focus overview is 637 logical pixels tall with full-size controls; explanations/raw keys are no longer repeated inline. The pinned map shows pending movement without changing the observed list summary. Keep/Revert and countdown remain visually distinct, with Revert initially focused.
- Narrow renders confirm the existing minimum-canvas horizontal overflow: the diagram stays pinned to the left pane, but is not a screen-fixed overlay when the viewport scrolls right to an editor. This is documented, not claimed as simultaneous visibility at emergency widths.
- Final isolated validation (`29b1fb6` plus step 5, excluding concurrent shared-action work): warning-fatal QML lint including the manual fixture passed; **324 native passes, zero failures**; visual fixture **4 passes, zero failures**; display/provider model and daemon-boundary checks passed. The fixture permits read-only snapshots and asserts that no mutation is dispatched.
- Built the isolated `shelllistConfig` Nix package and checked its installed relative imports successfully. Evidence: `/tmp/display-step5-isolated-{lint,full,captures,validation}.txt`, `/tmp/display-step5-package-check.txt`.
- The newer concurrent shared-header revision still had a `SurfaceActionRow.Window` lint warning when checked. It was not changed or included in this validation claim.

No service reload, deployment or hardware mutation was performed. Physical mode switching, docking, live compositor placement and screen-reader acceptance remain manual hardware checks.
