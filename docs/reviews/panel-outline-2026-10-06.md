# Panel outline clipping — 2026-10-06

The bottom outline was reported missing both on screen and in captures. The
initial screenshot-only explanation was insufficient.

## Reproduction and correction

Every panel inherits `Ui.ChooserSurface`. Its original 1px rectangle border was
painted directly against the surface/viewport boundary. At fractional scale,
placement and raster clipping can remove most of an edge stroke.

A temporary, nonfocusable Wayland layer surface reproduced the issue using the
installed Quickshell executable on the existing 125% output. The test surface
was 453×823 logical pixels at (1150, 190), matching the chooser's fractional
placement. The before/after comparison used the same window and changed only
the border treatment. An opaque test backdrop and padded capture at
pixel-aligned coordinates kept the capture boundary away from the panel edge
and excluded desktop content. The original bottom stroke had only **1.79:1**
peak contrast against the panel fill; the inset stroke reached **6.54:1**.
This demonstrates a composited edge problem, not merely cropping at the requested
screenshot rectangle.

`ChooserSurface` now paints a transparent outline rectangle inset by one logical
pixel, above its content. The fill still occupies the original rounded surface.
Placement, native window size, input mask, scrolling, content margins, focus and
command routing are unchanged. All panels inherit the same correction.

## Checks and limitations

- `tst_surface_outline.qml` checks actual painted edges with ordinary bounds and
  a conservative one-logical-pixel clipped-edge case. The clipped case fails
  against the original surface and passes with the inset outline.
- Native `grabToImage` checks at 1×, 1.25× and 2× retain all four edges. The live
  before/after comparison uses the user's existing 125% Wayland output.
- QtTest's `grabImage` at non-unit `QT_SCALE_FACTOR` cropped the physical image
  to logical dimensions in this environment. Fractional render evidence uses
  native `grabToImage`, not that test helper; the regular Qt suite uses its
  standard offscreen setup.
- Temporary native probes exited automatically. No resident Shelllist restart,
  deployment, compositor setting change or domain mutation was performed. The
  runtime theme's ordinary read-only bar-daemon connection remained in use.
  The probes emitted the existing host-portal duplicate-registration advisory;
  it was not suppressed or treated as a rendering failure.
- This targeted check is not general live-compositor, hardware-input or
  screen-reader acceptance.

Evidence lives in ignored `target/panel-outline/`: `qt-before.log`,
`native-after-{1,1.25,2}.{png,log}`, `native-padded-{before,after}.png`,
`pixel-checks.log`, `live-ab.qml` and `live-ab.log`.
