# Displays

Displays is an independent, lazy-loaded Shelllist surface. Open it with the
`displays` global shortcut, the surface rail, or
`shelllist open displays`. It uses the shared chooser host, theme, controls and
resident bar-daemon transport; opening it does not initialize Battery.

## Searchable callout

The compact view uses Shelllist's shared search and keyed result list. It lists
connected supported outputs, including disabled ones, with observed enabled state,
connector, resolution and refresh rate. Enabled displays sort first. Search uses
the shared Rust matcher over names, connectors and reported manufacturer/model or
serial metadata; it does not discover disconnected or wireless displays.

Up/Down selects a row; **Right** or its chevron expands that display's options
beside the list, keeping its left edge anchored. Narrow outputs retain this split
layout; below the supported canvas size, explicit scrolling and focus revelation
keep controls reachable. **Left/Escape** closes monitor details without a separate
back-arrow button; pending layout changes are protected by a discard confirmation. See [shared geometry](chooser-geometry.md) for bounds and limits.
Left closes details when not consumed by an editor or tab control. Returning
to the list restores search focus. Empty searches and disconnected displays have distinct messages, and
keyboard back navigation and draft recovery remain available even if the selected
display disappears.

The layout diagram sits at the top of expanded monitor details, above the
Settings/Information pages, rather than below search. It shows every connected
supported display, including disabled screens and mirrors, and highlights only
the selected display. It remains visible with one display and on either monitor
tab, but is absent from the compact list and global focus settings. Independent
screens use their draft desktop positions; disabled screens and mirrors are
labelled and placed beside the desktop so overlapping coordinates cannot hide
them. This presentation placement never changes the draft.

**Preview layout · not applied** marks pending changes. The diagram never takes
Tab/browse focus. Select displays using the list or pointer. Arrange enabled
independent displays using edge-snapping drag/drop or the **Left / Above / Below /
Right** buttons immediately below the map. Parked disabled/mirror tiles are
selection-only. On narrow outputs, the shared horizontal overflow/revelation
still applies.

The trailing **settings gear** inside search opens global Display settings,
even when search has no results or no display is selected. Alt+Enter from search
opens it too. Its presentation memory is independent of individual monitors.

## Selected display options

One prominent **Preview changes** button sits at the top of monitor details,
with distinct Preview/Identify symbols and two secondary actions:

- **Identify** marks the selected enabled screen for three seconds. It never
  enables a disabled screen or takes focus. The monitor icon beside search
  identifies all enabled screens.
- **Enable / Disable** changes any selected screen's draft, including the laptop.
  The last enabled display is protected. Confirmed manual enablement overrides
  docking policy until that preference is set again.

**Settings** contains mirror/extend content selection, resolution/refresh, scale
and rotation/reflection. Controls preserve advertised backend mode strings.
There are no X/Y fields or separate Position card; relative arrangement stays
with the map above both detail pages.
**Information** is read-only observed state, including connector, available
identity metadata, mode, logical size, scale and position and whether it is the
active monitor. Missing metadata is omitted. Ctrl+Tab cycles Settings and
Information; global Focus is accessed from the search gear, not a monitor tab.
Switching displays, tabs or global settings retains the complete layout draft.

All tabs use the same inset detail layout, themed cards, typography and fixed
footer as the other chooser surfaces. Settings groups individually labelled
controls into **Display content** and **Display settings** cards. Information groups
observed values into **Display status** and **Display information** cards, with
one column on narrow outputs and two where space permits. Cards grow with their
contents; the page scrolls without moving the tabs.

**Preview changes** is enabled only for a valid, changed layout. It previews the
**whole layout**, not just the selected screen. Unsaved/stale/error status and
Discard/Reload remain above the tabs. Narrow headers stack the primary button
above the secondary row, and settings scroll while tab controls stay visible.

## Relative arrangement

A monitor can be placed only **left, above, below or right** of another enabled
independent monitor. Left/right placements align the top edges; above/below align
the left edges. Logical dimensions account for scale and rotation, rounded to
integer pixels consistently for placement and collision checks.

- **Drag:** move a monitor tile to an edge of another monitor. The map makes room
  for possible destinations at drag entry, then freezes its fitting. A translucent
  tile and target outline show the destination, with a label naming the reference
  and side. Hovering does not change the draft. Release at a valid edge to place;
  Escape, an outside drop, loss of the pointer grab, hiding the view or a topology/
  geometry change cancels. Ordinary unchanged telemetry does not interrupt it.
- **Buttons / keyboard:** click the four buttons below the map, or use **Alt+L**
  (left), **Alt+U** (above), **Alt+D** (below), **Alt+R** (right). Plain arrows retain
  list/editor navigation. Buttons are commands, not Tab stops. With two eligible
  monitors the reference is automatic. With three or more, the reference name
  becomes a dropdown using the shared Enter/Tab save and Escape discard workflow.
  Selecting a reference alone never moves a monitor. A successful drop selects
  its target as the reference for subsequent button commands.

Both routes use the same validated operation and modify only the local draft.
Other monitors remain fixed. Destinations overlapping another independent screen
or exceeding supported coordinates are blocked with an explanation; invalid
ghosts are warning-coloured. Repeating the current placement is a no-op. Disabled
screens and mirrors are neither draggable nor reference targets, and the strip
explains when enabling/extending or connecting another screen is required.

Opening the panel never rewrites an observed layout. New overlaps introduced by
placement, enablement, resolution, scale or rotation block Preview until resolved.
Existing unchanged compositor geometry is preserved. Free-coordinate placement,
diagonal drops, pixel nudges and Alt-to-bypass-snapping are not available.

## Mirror or extend content

Select an enabled screen and open **Settings → Display content**. Choose:

- **Extend desktop** for independent content and an independently positioned desktop.
- **Mirror <display>** to duplicate that enabled, extended source's content.

Changes remain draft-only until **Preview changes → Keep**. You can mirror two
screens while a third extends, or attach several mirrors to one source. A mirror
cannot itself be a source; stop its copies first before making a source mirror
another display. Each physical screen can retain its own supported resolution,
refresh rate, scale and rotation. Different aspect ratios are fitted with black
bars rather than requiring identical modes.

Mirrors share the source's desktop, so their position controls are disabled and
the canvas shows them as separate labelled, selection-only screens beside the
desktop, not duplicate movable workspaces. Selecting Extend again places the screen beside the other extended
displays. Observed mirror relationships appear in the list and Information tab.

Disabling a source promotes its copies to extended displays; the daemon applies
those independent replacements before disabling the source. Source disconnection
also promotes surviving copies during recovery, while retaining the saved mirror
relationship for reconnect. Automatic docking cannot disable an active mirror
source or treat its copy as an independent fallback. Rollback and confirmation
verify mirror relationships as well as modes; simply accepting a command is not
proof that mirroring worked.

## Laptop docking settings

Select the laptop screen, including when it is off, and open **Settings → When
docked**. Choose **Keep laptop screen on** or **Turn off automatically** when an
external display is available. Enter edits the preference; Enter/Tab submits it
without a layout preview, and Escape discards it. The editing highlight shows a
local choice; outside editing the displayed value changes only after daemon
acknowledgement. A failed save leaves the previous choice selected and reports the
error so the choice can be retried. This monitor-specific preference stays here rather than in global Focus settings.

The laptop returns automatically when no usable external display remains. A
policy-disabled laptop stays selectable in the list with **Off · External display
preferred**. The docking section is absent from external monitors' settings and
from desktop-only setups. It is locked while a layout draft or trial is pending,
with a reminder to finish or discard layout changes first. Resolution, scale,
rotation and position retain their existing Preview/Keep workflow.

## Monitor and window focus

Open the search **settings gear** for global Focus settings. The overview shows
three common controls: **Window focus**, **Activate monitor on pointer entry**,
and **Refocus on pointer movement**. Boolean settings use wrapping switch rows;
choices and numeric fields use responsive labelled editors. The remaining
controls live in separate category pages, rather than a long expanded form:

- **Pointer:** click/follow/detached/separate focus, monitor
  activation on pointer crossing, refocus thresholds/dead zones, floating-window,
  drag-and-drop, layer and special-workspace exceptions.
- **Keyboard:** cross-monitor directional navigation,
  history versus shared-edge target selection, fullscreen/group cycling, and
  workspace back-and-forth/history.
- **Applications:** activation requests, focus after closing,
  focus behind fullscreen, and launch-workspace tracking.
- **Cursor:** suppress or remember warps, workspace/special-workspace
  warps, cursor destinations, and restoration after non-mouse input.

Each setting has a keyboard/pointer-accessible help button for its longer
explanation. Raw compositor keys and acknowledged values appear only in
**Diagnostics**, alongside the active monitor and focused window's monitor.
This telemetry makes it clear when pointer-selected monitor and keyboard-focused
window differ. Back/Escape returns from a category or Diagnostics to Focus before
closing the details pane; editor Escape first discards the current field edit.
Category navigation retains per-page focus/scroll memory, not uncommitted edits.
These settings apply to **all** monitors. Choices and numbers use the shared
Enter/Tab save and Escape discard contract, not layout Preview; switches toggle
immediately on Enter. Alt+P/K/A/C opens Pointer/Keyboard/Applications/Cursor,
Alt+D opens Diagnostics, and Alt+H shows help for the current field.
Only reported compositor capabilities are editable; unsupported options are
labelled unavailable. Controls are locked during layout drafts/trials or loss of
transport, and a failed save keeps the acknowledged choice visible for retry.

Only explicitly edited settings become persistent overrides. They survive daemon
restart and compositor config reload without repeatedly rewriting working values.
**Diagnostics → Restore previous settings** removes the overrides and restores values
captured before their first edits. Future config reloads follow your Hyprland
configuration again; Restore is not a factory-defaults operation.

For keyboard-led monitor selection, choose **Click to focus** and turn off
**Activate monitor on pointer entry**, then review floating/drag exceptions.
Disabling pointer monitor activation alone does not prevent window focus from
activating another monitor. Explicit **last-window** and **focus-monitor** shortcuts
can still cross monitors: directional-navigation restrictions do not alter those
commands. This page does not rewrite keybindings or per-window rules, and does not
claim to lock all focus to one screen.

## Layout safety and keyboard controls

- Drag screens to a reference edge or use the four direction commands below the
  map. Only enabled independent displays can be arranged.
- The diagram is an accessible graphic, never a keyboard navigation stop.
  Select an output in the list; Alt+L/U/D/R places it relative to the shown
  reference. Escape cancels an active pointer drag without editing the draft.
- Preview or Ctrl+Enter sends the complete validated draft. Nothing moves live
  while editing. An unconfirmed trial reverts after 20 seconds, subject to daemon
  reconciliation and compositor availability. Revert has initial keyboard focus;
  Keep is a separate deliberate action. Held activation keys cannot repeat.
- Escape reverts a trial, returns from a global category to Focus, or returns to
  the compact view. Dirty drafts ask before discarding, including diagram edits. Incoming telemetry does not overwrite a draft. A changed topology
  or externally changed configuration blocks Preview until explicitly reloaded.
- Closing during a pending preview schedules a revert when its token arrives.
  Daemon rollback remains authoritative when the client or transport is lost.

## Ownership

`bar-daemon` remains the only display configuration owner. Enable
`programs.shelllist.displays.enable` to permit changes. Existing preferences,
layout journals and `monitors.lua` are preserved. Display settings never change
lid actions, suspend policy or DPMS. Battery & Power no longer owns display state,
requests, subscriptions or controls.

The daemon normalizes connector support/internal classification, exact current
mode IDs, structured mode catalogs (`id`, `width`, `height`, `rate`, `size`) and
mirror references in every snapshot and event. Shelllist does not parse raw
`availableModes` or resolve compositor monitor IDs. Drafts retain their snapshot's
mode catalog for local canvas geometry; only mutation fields are sent on Preview.
Field save/discard, labels, snapping and layout placement remain local. Deploy the
matching daemon and frontend together; there is no legacy JS normalization fallback.

No named profiles, workspace assignment, HDR/VRR or competing display manager
is introduced. Those require separate backend capability/transaction work.

## Relative-arrangement validation

The [approved arrangement plan](proposals/display-relative-placement.md) records
the design and delivery. Validation passed 41 focused Displays Qt checks, 279 full
QML checks, four visual-fixture checks, strict QML lint, pure geometry/model checks,
daemon-boundary checks and relative-import resolution. Light/dark captures cover
2/3 screens, drop ghosts, disabled/mirrored screens and short/narrow layouts.
No live mode switch, deployment or service restart was performed.

## Earlier focus-settings redesign validation

See [the five-step review](reviews/display-settings-redesign.md) for the current
search-gear/global-settings routing, persistent diagram, focus-category design,
keyboard/geometry coverage and light/dark capture evidence. The final isolated
redesign passes strict lint, 324 native checks and four visual-fixture checks,
plus model/daemon-boundary and installed-package import validation. Concurrent
shared-action changes were excluded from that isolated validation claim.

## Historical searchable chooser validation

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
