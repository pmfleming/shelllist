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

No service reload or hardware mutation is part of these tests.
