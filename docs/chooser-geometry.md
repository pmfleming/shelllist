# Anchored chooser geometry

This delivers the geometry slice of step 4 in the
[Material Expressive plan](proposals/material-expressive.md).
[Session memory](chooser-session-memory.md) is delivered by subsequent slices:
per-result presentation and ordinary invocation focus for Applications/Bluetooth.

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
  stay 64px high after the Material segmented-list pass; a shorter viewport
  shows fewer rows, not smaller targets.
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

Notifications uses the shared anchored list/inspector surface, with one selected
message or independent settings page in the inspector.
Activity now has its glance rail on the left and expands Schedule to the right;
its former full-height, right-edge special placement is removed. Displays no
longer switches to a detail-only layout. Domain settings, recovery, preview/revert
and prompt policies are unchanged. Activity's content and the remaining domains'
keyboard models still await their own migration.

## Detail content sizing

Expanded command headers use a shared title/icon band with a right-aligned 56px
primary circle, and a separate right-aligned row of 48px secondary circles when
present. Text reserves the primary diameter plus a 16px gap and elides. The
secondary row fits independently, overflowing to More rather than shrinking or
stretching buttons. Header natural height is subtracted from the scrolling body;
result-list anchoring and the supported split envelope are unchanged. Empty
command rows take no height. Wi-Fi uses the same unscaled header/control geometry
rather than reducing targets with viewport height.

Settings cards grow from their content, not a fraction of the viewport height.
Toggle rows retain their natural height (at least 56px); wrapped labels can grow
further. Short viewports scroll rather than compressing controls into the next
card. This applies to Wi-Fi profile/IP settings and the shared card layouts used
by Bluetooth, Battery, Applications and Clipboard.

Diagnostic grids switch to one column when two 160px fields no longer fit.
Their natural height includes wrapped labels and spacing; containing cards and
always-visible sections reserve that height. Wi-Fi segmented/IP fields also stack their
labels above controls at narrow widths.

The dedicated shared-layout catalogue was removed during the
[2026-10-04 test pruning](reviews/test-pruning-2026-10-04.md). These sizing rules
remain the intended behavior, but every card/width combination is no longer
individually checked.

## Validation

`tst_chooser_geometry.qml` retains negative-origin work areas, absent-data
fallback, single-column geometry, live/fractional list anchoring, filtering,
live resize, focused-delegate routing and keyboard overflow revelation.
Displays retains numeric validation, topology, preview/revert and disconnect
checks. Repeated size matrices and the Activity-specific rail test were removed;
see [current test scope](../tests/README.md) for validation and explicit gaps.

At the original geometry checkpoint, strict lint, **141 behavioral cases / 215
Qt passes including hooks**, runtime smoke and the full sibling-aware gate passed.
Those results and the normal/minimum/emergency light/dark Applications capture
review are historical, not fresh acceptance of the pruned suite. Real focused
result delegates use the same query/guard/detail-focus route as the list; the
geometry tests exposed their legacy key handlers bypassing that boundary.

The native floating-window smoke checks shared visual bounds without touching a
live compositor. Its offscreen plugin prints the expected advisory
`This plugin does not support setting window masks`; this is not a QML error. Offscreen Qt cannot instantiate a layer-shell `PanelWindow` or
apply native input masks; actual click-through, monitor routing, fractional-scale
rendering and compositor placement still require live acceptance. No service is
restarted or deployed by these tests.

Validation logs: `/tmp/shelllist-geometry-validation.log` and
`/tmp/shelllist-geometry-full-check.log`. See the
[quality gate guide](qml-quality-review.md) for the sibling-aware check command.
