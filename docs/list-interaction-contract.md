# List interaction contract

Every vertically scrollable Shelllist result, menu, history, and detail list uses `Shelllist.Ui.ScrollableListView`.

The component preserves the normal `ListView` API and guarantees:

- direct touch dragging and kinetic flicking remain available;
- precision touchpad two-finger gestures use Qt's native pixel-delta scrolling;
- mouse wheels use Qt's native angle-delta scrolling;
- platform direction, acceleration, and high-resolution wheel behavior are preserved;
- movement is vertical and content stops at the list bounds;
- delegate hover and click layers pass wheel events through to the list.

Domain views must not declare raw `ListView` objects or add wheel handlers to list delegates. `StateLayer` passes wheel events through by default. A non-list action that intentionally maps wheel input to an action must set `consumeWheel: true`; currently this applies to bar actions and tray items.

`tests/check-list-scroll-contract.js` enforces shared-list use and wheel ownership. The runtime smoke test validates that the exported component loads with the shared UI module.
