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

No service reload or hardware mutation is part of these tests.
