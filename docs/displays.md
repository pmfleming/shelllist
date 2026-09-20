# Displays

Displays is an independent, lazy-loaded Shelllist surface. Open it from the monitor
control beside brightness, the `displays` global shortcut, or
`shelllist open displays`. It uses the shared chooser host, theme, controls and
resident bar-daemon transport; opening it does not initialize Battery.

`bar-daemon` remains the only display configuration owner. Enable
`programs.shelllist.displays.enable` to permit changes. Existing preferences,
layout journals and `monitors.lua` are preserved. Display settings never change
lid actions, sleep policy or DPMS.

## Delivery checkpoints

1. **Independent surface and routing:** display-only controller/backend,
   acknowledged policy changes, existing layout preview form, bar/CLI/shortcut
   entry points, packaging and isolated QML tests. Power's old cards remain
   temporarily until the visual replacement is ready.
2. **Compact callout and layout workspace:** diagram-first summary and expanded
   visual editor, shared controls and keyboard navigation; remove Power's display
   cards and ownership at this checkpoint.
3. **Safety and verification:** geometry/lifecycle tests, daemon conflict guards,
   narrow-screen/focus checks, docs and packaging validation. Mirroring, named
   profiles and new preset transactions are intentionally outside this delivery.

Stage 1 validation: focused Displays QML tests (5 passed), strict qmllint for the
new module and surface registry, TypeScript presentation regenerated.
