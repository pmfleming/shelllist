# Anchored chooser geometry

This delivers the geometry slice of step 4 in the
[Material Expressive plan](proposals/material-expressive.md). Per-result session
memory and ordinary-focus restoration are still separate work.

## Placement and bounds

All resident surfaces now use `Ui.PopoverGeometry` and the same focused-screen
work-area source. Coordinates are logical pixels, including negative monitor
origins and fractional-scale outputs. The daemon supplies reserved space/gaps;
QScreen supplies the screen rectangle. Missing/disconnected work-area data falls
back to bounded screen geometry. Opening does not wait for that data. Changes to
the monitor/work area can reposition the surface; opening details cannot.

The 453px list frame is centered when room permits. Otherwise its left edge is
shifted left only far enough to fit the eventual right-hand inspector. The host
reserves a maximum-width window, but its visual surface and input mask cover only
the current content width. Reserved space is not painted or included in that
input region. The list's left edge stays fixed throughout expansion/collapse.
Screenshots use that same content origin and the actual bounded visible size.

- Normal outer/inner horizontal margins are 14px, with a 12px detail gap.
- Below 1200px work-area width or 800px height, margins/gap tighten to 8px.
  Legacy automatic chooser font/control scaling is removed. Shared result rows
  stay 52px high; a shorter viewport shows fewer rows, not smaller targets.
- Expanded canvas width is 960–1040px. The inspector has at least 495px before
  its own padding. The list is not replaced by details on small outputs.
- Frame height is 75% of work-area height, bounded to 360–900px and clamped to
  the available area. Search, result count and telemetry do not size the frame.
- The tested supported split envelope is **976×600 logical work-area pixels**
  or larger at the default font sizes. This is a measured implementation bound,
  not a new owner requirement or a claim of large-text accessibility acceptance.

Below the canvas bounds, `Ui.SurfaceViewport` provides explicit horizontal and,
for very short outputs, vertical scrollbars. Focus reveals native controls;
Applications/Bluetooth also reveal their separate detail browse cursor. Returning
to search/results reveals the list again. Emergency scrolling can move the list
out of the viewport, but never destroys/replaces it or changes the split model.
Wheel/touchpad/touch scrolling and scrollbar dragging remain native Qt behavior;
outer mouse dragging is disabled so it cannot steal text-selection drags. Very
small viewports may require panning across a control wider than the viewport.

Notifications remain a single-column surface and reserve no inspector space.
Activity now has its glance rail on the left and expands Schedule to the right;
its former full-height, right-edge special placement is removed. Displays no
longer switches to a detail-only layout. Domain settings, recovery, preview/revert
and prompt policies are unchanged. Activity's content and the remaining domains'
keyboard models still await their own migration.

## Validation

`tst_chooser_geometry.qml` covers minimum/laptop/desktop/ultrawide and emergency
bounds, negative-origin work areas, absent-data fallback, single-column geometry,
animated list anchoring, filtering, live resize, stable text/control sizes,
native editor/browse visibility,
return-to-search overflow and the actual Activity glance rail. The Displays
regression now exercises the split overflow viewport rather than prescribing the
rejected single-pane layout; numeric validation, trial and disconnect checks
remain intact.

Strict lint, **141 behavioral cases / 215 Qt passes including hooks**, runtime
smoke and the full sibling-aware gate pass. Light/dark Applications captures were
reviewed at normal, minimum-width and emergency-overflow sizes. Real focused
result delegates also now use the same query/guard/detail-focus route as the list;
the geometry tests exposed their legacy key handlers bypassing that boundary.

The native floating-window smoke checks shared visual bounds without touching a
live compositor. Its offscreen plugin prints the expected advisory
`This plugin does not support setting window masks`; this is not a QML error. Offscreen Qt cannot instantiate a layer-shell `PanelWindow` or
apply native input masks; actual click-through, monitor routing, fractional-scale
rendering and compositor placement still require live acceptance. No service is
restarted or deployed by these tests.

Validation logs: `/tmp/shelllist-geometry-validation.log` and
`/tmp/shelllist-geometry-full-check.log`. See the
[quality gate guide](qml-quality-review.md) for the sibling-aware check command.
