# Display arrangement: relative placement only

Status: **approved and implemented**. The linked image is the original design
proposal, not a runtime screenshot.

Mockup: [PNG](display-relative-placement.png) · [editable SVG](display-relative-placement.svg).
The mockup deliberately shows both screens enabled to demonstrate positioning.

## Proposed UI

- Keep the full display map at the top of expanded monitor details, showing all
  connected supported displays and highlighting only the selected monitor.
- Remove the entire **Precise position / Position** card: no X/Y fields and no
  second arrangement control further down the page.
- Directly below the map, show four labelled buttons in this order:
  **← Left · ↑ Above · ↓ Below · → Right**.
- State the selected and reference monitors immediately above the buttons:
  **Move HDMI-A-1 relative to Laptop (eDP-1)**.
  With two enabled independent screens the reference is automatic/read-only.
  With three or more, make only the reference name a shared dropdown. This is
  a target selector, not a third positioning method. Only eligible other screens
  appear in it; remember the reference while it remains eligible.
- Keep Preview changes, Identify, enable/disable, discard/reload, and the
  Settings/Information pages. Do not restore the monitor-details back arrow.
- The arrangement strip stays with the map on both detail tabs; global Focus
  settings remain separate. Use existing scrolling/minimum geometry rules on
  short/narrow windows rather than shrinking buttons or hiding settings.

## Interaction 1: drag to a side

1. Press and drag an enabled independent monitor tile. A simple click still
   selects a monitor without changing its position.
2. Hover near another enabled independent monitor's left, top, bottom or right
   edge. Show the target outline, a translucent snapped destination, and a short
   label such as **Place HDMI-A-1 above eDP-1**. Choose the nearest eligible edge;
   use a small dead band to avoid flickering between sides at corners.
3. Release over a valid destination to update the local layout draft exactly
   once. Dropping elsewhere, pressing Escape, losing the pointer grab, or
   receiving a topology change cancels without changing the draft.
4. Update the reference caption to the drop target. Freeze map fitting while
   dragging; refit after drop/cancel so tiles do not move beneath the pointer.

No free-coordinate drop, diagonal placement, pixel nudging, or Alt-to-disable
snapping. The floating drag representation is only feedback, never a committed
arbitrary position.

## Interaction 2: buttons / keyboard

- Clicking a direction places the selected monitor on that side of the reference.
- Use the existing command letters: **Alt+L** left, **Alt+U** above, **Alt+D** below,
  **Alt+R** right. The image shows the shortcut-hint state for illustration;
  actual badges follow the shared held-Alt behavior.
- Plain arrows retain normal list navigation and native editor behavior. Buttons
  do not enter the Tab chain, following the shared chooser keyboard contract.
- With 3+ independent enabled screens, Tab reaches the reference dropdown;
  Enter edits, native arrows choose, Enter/Tab saves and Escape cancels. Changing
  the reference alone never moves a monitor or sends a backend write.
- Both placement methods call the same validated relative-placement operation.
  Repeating the already-current placement is a no-op.

## Geometry and safety decisions

- Side placement is edge-to-edge with no gap. Left/right align the top edges;
  above/below align the left edges. Calculate from logical dimensions, including
  scale and rotation, and round consistently for the daemon's integer positions.
- Moving a screen does not silently move other screens. If the candidate overlaps
  a third independent display or exceeds supported coordinates, mark it invalid,
  disable that direction and explain why. A drag to that candidate cannot commit.
  The user can choose a different reference/side instead.
- Existing compositor coordinates remain untouched on opening the panel, even if
  they contain offsets/gaps. Only an explicit placement changes that screen.
  Resolution/scale/rotation changes must revalidate placement before Preview;
  do not silently rewrite an unrelated screen's arrangement.
- Disabled screens and mirrors remain visible and selectable in the map's
  separate parked area. They are neither draggable nor eligible reference
  monitors. Show **Enable this display to arrange it**, **Mirrors <source>**, or
  **Connect another extended display to arrange** instead of enabled buttons
  where appropriate. A mirror cannot be independently positioned.
- Keep all existing canEdit, pending action, trial, stale topology, last-enabled,
  discard, backend validation and Preview → Keep / timed Revert protections.
  Dragging/buttons edit only the draft, never the live compositor.

## Implementation sequence (completed)

1. `displays/DisplayModel.js`: add a shared relative-placement candidate/validity
   helper for dimensions, side, collision and bounds checks. Retain coordinate
   payloads at the existing daemon boundary; no protocol change is needed.
2. `displays/DisplayController.qml`: route direction actions and accepted drops
   through that helper; filter references to other enabled independent outputs,
   expose per-side availability/reasons, and preserve existing safety guards.
3. `displays/DisplayCanvas.qml`: replace free movement with a cancellable
   target/side drag preview. Keep the selected display highlight, parked screen
   visibility, stable pointer grabs, and non-focusable graphic behavior.
4. `displays/DisplayDetails.qml`: place the shared arrangement strip directly
   below the map. `displays/DisplayInspector.qml`: remove the old position card.
   Remove obsolete UI-only free-movement paths after checking their callers.
5. Update display documentation and geometry/model/native interaction tests.
   Capture approved light/dark, 2-screen/3-screen, disabled/mirror and short/narrow
   states. Do not deploy until checks pass and deployment is requested.

## Acceptance checks

- Each of four button actions and each drag edge produces the same coordinates.
- Mismatched dimensions, fractional scales, rotation and negative origins work.
- Overlapping/invalid destinations are blocked with a reason; no backend writes
  occur on hover, cancel, reference changes, or local draft placement.
- Selection, target switching with 3+ screens, Alt commands and ordinary arrow/
  Tab editing contracts remain correct; no command shortcut collisions.
- Disabled/mirrored screens, one-screen layouts, unplug during drag, stale drafts,
  trial/pending guards, cancelled pointer grabs and Escape are covered.
- The map/buttons stay together above settings, no X/Y controls remain, all
  screens are drawn, and Preview/Keep/Revert retains its existing behavior.

## Delivery notes

The user approved the layout and edge-alignment rule. The implementation includes
`DisplayArrangementControls.qml` beside the map, transient edge ghosts, shared
placement/collision checks, target selection, guarded Alt commands, and removal
of the old X/Y card. The map moves out of the list into expanded details; disabled
and mirrored screens remain visible without being draggable. The monitor-details
back arrow and its otherwise-empty status row are absent.

To fit all possible destinations, the map zooms out once after the drag threshold
is crossed, then freezes the transform for the gesture. Clicking alone never
zooms or edits. Reference tiles retain connector labels at smaller drag sizes.
An unchanged daemon snapshot no longer rebuilds a clean draft during a gesture.

Validation:
- 41 focused Displays Qt checks passed, including native pointer/key delivery.
- Pure display model checks, strict repository QML lint, daemon-boundary checks
  and relative-import resolution passed.
- Four visual-fixture checks passed. Light/dark renders were inspected for
  two/three monitors, edge-drag preview, disabled/mirrored screens and short/narrow
  views. Captures are generated under `target/display-settings-review/`.
- The final full QML run passed **279 checks, zero failures**. An earlier run
  encountered five Notifications failures during concurrent edits; the final
  rerun is clean. No unrelated notification changes are included in this commit.

No live monitor configuration, running service or system deployment was changed.
