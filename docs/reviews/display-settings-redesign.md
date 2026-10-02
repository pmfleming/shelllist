# Display settings redesign

## Step 1 — independent global settings

- Search's trailing settings action opens global Focus without a selected or connected monitor.
- Monitor details retain Settings/Information; global presentation memory has its own key.
- Global pages do not expose layout actions or the layout-preview shortcut.
- Context switches preserve the existing details loader and per-monitor tab memory.
- Validation: strict QML lint passed; Displays Qt suite: 20 passes, zero failures (including hooks).

No service reload or hardware mutation is part of these tests.
