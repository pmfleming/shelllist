# Displays

Displays is an independent, lazy-loaded Shelllist surface. Open it from the monitor
control in the bar, the `displays` global shortcut, or
`shelllist open displays`. It uses the shared chooser host, theme, controls and
resident bar-daemon transport; opening it does not initialize Battery.

## Searchable callout

The compact view uses Shelllist's shared search and keyed result list. It lists
connected supported outputs, including disabled ones, with observed enabled state,
connector, resolution and refresh rate. Enabled displays sort first. Search uses
the shared Rust matcher over names, connectors and reported manufacturer/model or
serial metadata; it does not discover disconnected or wireless displays.

Up/Down selects a row; **Right** or its chevron expands that display's options
beside the list. The compact diagram is replaced by this list. On narrow outputs,
details occupy the available width and **Back to displays** returns to the list.
Left closes details when not consumed by an editor, canvas or tab control; Left
inside a position field moves its cursor. Returning to the list restores search
focus. Empty searches and disconnected displays have distinct messages, and Back
and draft recovery remain available even if the selected display disappears.

## Selected display options

One prominent **Preview changes** button sits at the top, with two or three
secondary buttons below it:

- **Identify** marks the selected enabled screen for three seconds. It never
  enables a disabled screen or takes focus. The monitor icon beside search
  identifies all enabled screens.
- **Arrange** switches to Settings and reveals the logical-size layout canvas.
- **Enable / Disable** changes the selected external screen's draft only. Internal
  enablement remains owned by docking policy, so this button is omitted for it.

**Settings** contains resolution/refresh, scale, rotation/reflection, X/Y position,
and relative placement. Controls preserve advertised backend mode strings. The
optional canvas stacks above the inspector below 740 logical pixels; it can be
hidden without discarding edits. **Information** is read-only observed state,
including connector, available identity metadata, mode, logical size, scale and
position. Missing metadata is omitted. Ctrl+Tab cycles the two tabs. Switching
displays or tabs retains the complete layout draft.

**Preview changes** is enabled only for a valid, changed layout. It previews the
**whole layout**, not just the selected screen. Unsaved/stale/error status and
Discard/Reload remain above the tabs. Narrow headers stack the primary button
above the secondary row, and settings scroll while tab controls stay visible.

## Display-wide settings

The gear beside search (also Alt+Enter in search) opens display-wide settings,
independently of the selected result. **Prefer external** saves docking policy
only after daemon acknowledgement. It is not a temporary mode selector. Laptop
fallback returns when no usable external display remains. The switch is hidden
on desktop-only setups and locked while a layout draft or trial is pending.
Escape closes this settings menu before returning from details.

## Layout safety and keyboard controls

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
lid actions, suspend policy or DPMS. Battery & Power no longer owns display state,
requests, subscriptions or controls.

No mirroring, named profiles, workspace assignment, HDR/VRR or competing display
manager is introduced. Those require separate backend capability/transaction work.

## Searchable chooser validation

The chooser refactor retains the daemon protocol and rollback behavior. Focused
QML coverage includes search/selection, live action identity, action hierarchy,
Settings/Information, draft retention, empty-selection hotplug recovery, cursor
navigation and action/tab geometry at 320, 390 and 1040 pixels. Existing preview,
confirmation, reconnect, topology and pending-close tests remain in place.
Validation passed: 20 focused Displays QML cases, 230 full QML cases, warning-fatal
QML lint, display/provider model checks, daemon boundary checks, packaged imports,
and the complete current-worktree Nix gate (including TypeScript and contracts).
Offscreen compact, Settings, Information, Arrange and narrow renders were inspected
using a non-mutating fixture. Physical mode switching/docking remains a manual
hardware acceptance check; no running service is replaced by these tests.

## Initial delivery checkpoints

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

Stage 3: 12 focused Displays QML tests and 230 full QML tests passed. Pure geometry
and payload validation, strict QML lint, generated TypeScript, packaged imports,
bar-api contracts and the complete current-worktree Nix check passed. The first
full check exceeded its time budget rebuilding dependencies; the cached retry
completed successfully. Fifteen focused bar-daemon display-policy/layout tests
also passed, including replacement ordering, topology replacement, durable policy
conflict rejection, restart/resume, monotonic expiry and failed rollback recovery.

The packaged module was loaded in Quickshell using a non-mutating fixture and no
visible windows. Identify's layer-shell type requires a Wayland backend, so that
load check used Wayland rather than Qt's offscreen platform. Actual docking,
physical mode switching, lid behavior and suspend/resume remain the manual
hardware acceptance matrix. No running shell/daemon service was replaced or
activated by this implementation.
