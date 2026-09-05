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

When a warm chooser is reopened, its result list reveals the existing logical selection without changing that selection. An edited first item therefore reopens at the top, while an edited item in the middle remains selected and is brought back into view.

The runtime smoke test validates that the exported component loads with the shared UI module, and `tst_result_list_reactivation.qml` checks that reopening reveals an offscreen selection without changing it. Shared-list use and wheel ownership remain review requirements rather than source-token assertions.
