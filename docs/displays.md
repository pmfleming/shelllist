# Displays

Displays is an independent, lazy-loaded Shelllist surface. Open it from the monitor
control beside brightness, the `displays` global shortcut, or
`shelllist open displays`. It uses the shared chooser host, theme, controls and
resident bar-daemon transport; opening it does not initialize Battery.

## Compact callout

The diagram shows actual connected output geometry and enabled state. Numbered
output rows open the selected display in the layout workspace; **Arrange** expands
the surface using the common chooser animation. The eye icon identifies enabled
screens for three seconds, without enabling disabled displays or taking focus.

The **Prefer external** switch saves docking policy immediately after daemon
acknowledgement. It is not a temporary mode selector. Laptop fallback returns
when no usable external display remains. The switch is hidden on desktop-only
setups and locked while a layout draft or trial is pending.

## Layout workspace

The workspace combines a logical-size map and a shared-control inspector. Below
740 logical pixels the inspector stacks beneath the canvas in a scrollable page.
Resolution and refresh controls preserve advertised backend mode strings. Scale,
rotation/reflection, X/Y position and external enablement are editable. Relative
placement arrows position the selected screen beside the chosen reference screen.
Internal enablement remains owned by docking policy; previews retain its fallback.

- Drag screens to align edges; hold Alt to bypass snapping.
- On the canvas, `[` / `]` select an output. Arrows (or h/j/k/l) move by 16 logical
  pixels, Shift by 1, Control by 64. Tab leaves the canvas for ordinary controls.
- Preview or Ctrl+Enter sends the complete validated draft. Nothing moves live
  while editing. An unconfirmed trial reverts after 20 seconds, subject to daemon
  reconciliation and compositor availability. Revert has initial keyboard focus;
  Keep is a separate deliberate action. Held activation keys cannot repeat.
- Escape reverts a trial, or returns to the compact view. Dirty drafts ask before
  discarding. Incoming telemetry does not overwrite a draft. A changed topology
  or externally changed configuration blocks Preview until explicitly reloaded.
- Closing during a pending preview schedules a revert when its token arrives.
  Daemon rollback remains authoritative when the client or transport is lost.

## Ownership

`bar-daemon` remains the only display configuration owner. Enable
`programs.shelllist.displays.enable` to permit changes. Existing preferences,
layout journals and `monitors.lua` are preserved. Display settings never change
lid actions, sleep policy or DPMS. Battery & Power no longer owns display state,
requests, subscriptions or controls.

No mirroring, named profiles, workspace assignment, HDR/VRR or competing display
manager is introduced. Those require separate backend capability/transaction work.

## Delivery checkpoints

1. Independent surface and bar/CLI/shortcut routes; isolated backend and tests.
2. Compact diagram, workspace, Identify, common controls and keyboard navigation;
   remove the old Power cards and display ownership.
3. Safety hardening, lifecycle/geometry tests, packaging and regression checks.

Stage 1: focused QML tests (5 passed), strict module/registry qmllint, generated TS.
Stage 2: focused QML tests (8 passed), full QML suite (226 passed), strict
module/registry qmllint, migrated Battery tests and bar presentation tests.
The direct local Qt runner lacked the SVG image plugin for unrelated weather/map
fixtures; those warnings did not fail tests. Offscreen compact, wide and narrow
renders inspected; no physical outputs were modified during development.
