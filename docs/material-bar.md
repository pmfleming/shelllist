# Balanced icon-only bar

The accepted balanced-dashboard revision keeps one continuous rounded surface
inside the existing **51px exclusive zone**. It does not introduce floating pods,
hover tooltips, new backend operations or a different panel-navigation model.
The [interaction contract](chooser-keyboard-workflow.md) remains normative.

## Composition and responsive geometry

- **Workspaces left:** fixed 32px category targets, with a quiet rounded selected
  tile. Shell, Browser, Code, Media and Text map to workspaces 1–5. The shared
  `Core/WorkspaceCategories.js` also supplies Applications' category setting;
  labels, icons and routing cannot drift between the two consumers. The bar
  renders only category glyphs, not names or the focused application's icon.
  Higher workspace IDs retain numeric fallback.
- **Media centered:** artwork plus Back, Play/Pause and Forward in a passive tonal
  pill. Media uses the screen center while it fits; otherwise its position is
  clamped between the measured workspace and status edges. It never overlaps
  either edge group, including during metadata or clock changes.
- **Status right:** Network, Bluetooth, Battery, Notifications, Tray, Clock/date.
  Passive separators distinguish radios from power and the clock. Healthy
  status uses theme foregrounds; daemon warning/critical and notification urgency
  remain visible. Only the numeric time/date appears as text in the bar.

There are no workspace/category/track labels or persistent battery/notification
numbers. Full descriptions remain in accessible names and the existing choosers.
All colors use shared theme roles; no proposal palette is hard-coded.

Selection, occupancy dots and urgency outlines/marks are distinct and immediate.
Workspaces remain independently scrollable, reveal the active workspace, and
retain an aggregate urgency indicator when a workspace is clipped. Selection
changes only on compositor snapshots, never on request admission or restoration.
Workspace allocation is capped at 27% of the output width.

Smaller widths reduce decorative spacing and omit the numerical date. They do
**not** hide media transport. Below the complete strip's minimum width, the existing
forward/back overflow button and horizontal scrolling reveal the unchanged
controls. No target or font is silently shrunk to fit. Missing players and
unsupported transport actions retain their geometry but cannot activate.

## Direct media actions

Artwork (or its missing/failed-image music fallback) opens the existing Media
panel in one click. It cannot play, seek or pin a player. Back, Play/Pause and
Forward invoke independent capability-guarded operations and never open the
panel. There is no disclosure step, hover reveal or compact artwork-only mode.
Group padding and gaps have no action; hover/press feedback stays local to each
button. Controls do not acquire panel field Tab stops or browsing markers.

`bar-daemon` still owns player selection, acknowledged playback and per-player
mode preferences. Automatic selection follows recently started playback; an
explicit pin wins until removed or the player exits. Inspecting/restoring a
player does not pin it. Music uses Previous/Next; unknown/video/podcast content
uses −30/+30 second seeking, with existing per-player overrides and independent
capability checks. No unavailable seek is replaced with a misleading track action.
See [Media](media.md) for panel presentation, metadata and routing policy.

## Battery: charge inside, state outside

Battery remains one action opening the existing Battery chooser. Its upright
silhouette has an inset, clipped continuous bottom-up fill. Charge never fills
the terminal, border or reserved external mark slot.

- A static **bolt** means charging.
- A **plug** means connected but not charging; 80% holding stays 80%, not full.
- A **check** means reported fully charged (or plugged at 100%, not charging).
- A **warning mark** accompanies daemon warning/critical state on battery.
- An external **unknown mark** and dashed body identify unavailable or malformed
  readings. Missing/null/non-finite percentages are not coerced to zero.

Marks sit outside the body with a real gap, clipped to their own slot so even a
fallback font cannot paint over the fill. They are passive children of the same
42px Battery action. The slot remains reserved when empty; status targets do not
shift with charging state. Known percentages are clamped to 0–100, but low and
critical states come from the daemon, not frontend thresholds. The accessible
name retains percentage, charging/holding state, warnings and detailed readings.

Only known fill updates may interpolate for **160ms** through shared
`InteractiveBehavior`; reduced motion removes interpolation. Glyphs, warning
colors and unknown state update immediately. No looping charge sweep, pulse or
animation invents telemetry. Rendering/inspection never writes a power setting.

## Clock, routes and compositor boundaries

Time and date are one direct Time & Weather action: `HH:mm` with quieter `MM-dd`
at comfortable density, time only at compact density. The separate trailing
clock icon is removed. The full date and timezone remain in the accessible name.
Updates remain aligned to minute boundaries.

Network opens Wi-Fi, with right-click portal fallback through the existing
owned portal transaction. Bluetooth and Battery open their choosers. The bell
opens Notifications; right click opens Activity; middle click toggles DND.
Urgency remains visible under DND. Tray's ellipsis opens its chooser at every
density; tray application icons are never placed inline in the bar.

Audio, Displays, power profiles, Applications, Activity, updates and other
existing surfaces retain their independent CLI/global-shortcut routes. There are
no invented quick-setting backend APIs. Submitted operation, retry, safety and
acknowledgement behavior is unchanged.

The continuous surface remains 94%-opaque. Transparent outer margins stay
outside the bar input mask. Hyprland blur/no-animation rules remain namespace
scoped and are reapplied after config reload. Neither the reserved zone nor native
layer-shell focus behavior changes in this revision.

## Validation

- `tst_balanced_dashboard.qml`: real workspace pointer/key routes and snapshot
  acknowledgement, stable category identity, numeric fallback, workspace reveal,
  urgency, center/collision bounds at 3440/1200/760/600/300px, actual overflow and
  combined-clock activation, battery state/unknown boundaries, external-mark
  pointer/accessibility activation, light/dark fill pixels and snapshot bindings.
- `tst_media_chip.qml`: direct artwork and tracks/seek routes at comfortable and
  compact widths, unchanged geometry on artwork/player loss, disabled actions,
  passive padding, local feedback and rounded-artwork rendering. The last pixel
  check additionally needs an RHI renderer.
- `tst_bar_material.qml`: no panel browsing caret or new Tab traversal, tray
  inventory isolation and native action routes. Applications' settings tests
  continue checking the shared category mapping, save/discard and acknowledgement.

Run `tests/run-qml-tests.sh`, `tests/run-qmllint.sh`, generated-source freshness and
TypeScript checks in the development environment. Native offscreen tests do not
claim live compositor blur/input-mask behavior, real hardware operations,
fractional-output acceptance or screen-reader acceptance; those remain separate.
