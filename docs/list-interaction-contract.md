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

When a warm chooser is reopened, its result list reveals the existing logical selection without changing that selection. An edited first item therefore reopens at the top, while an edited item in the middle remains selected and is brought back into view. The controller's selection is authoritative: after model mutations, `ResultListFrame` reconciles Qt's internally moved current index before revealing the row. A `currentIndex` binding alone is insufficient when a content-derived ID is replaced but the logical index stays unchanged.

Provider choosers and the bar share `Core.KeyedListModel`. Values must have
unique stable string `key` fields; delegates receive `resultKey` and `resultData`.
Small updates preserve delegates through moves/inserts/removals. Large replacements
remain progressive, and replacing or clearing values invalidates queued chunks.
Do not add another reconciliation loop in a domain view. Domain-specific row
selection and refresh behavior override `ResultRow.pick()` and
`ChooserListPane.requestRefresh()` rather than assigning callback properties.

The runtime smoke test validates that the exported component loads with the shared UI module, and `tst_result_list_reactivation.qml` exercises reopening, edited-ID replacement through the real keyed result store, and progressive fills. It also checks that normal scrolling can move away from the selection. Shared-list use and wheel ownership remain review requirements rather than source-token assertions.
