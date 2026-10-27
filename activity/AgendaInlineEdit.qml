import QtQuick
import Shelllist.Ui as Ui

// Domain snapshot collaborator, not an editor/control or navigation region.
// Shared FieldEditSession owns all keys, native buffers and save/discard. This
// helper freezes only accepted target/compound data at begin, never at save.
QtObject {
    id: transaction
    required property AgendaController controller
    required property Ui.FieldEditSession session
    required property string fieldKey
    property string childId: ""
    property string childField: ""
    property var snapshot: null

    function begin(): void {
        const current = controller.selectedItem;
        if (!controller.canWrite(current)) { snapshot = null; return; }
        const failed = controller.savedDrafts[current.id + ":" + fieldKey];
        const item = controller.copy(failed?.baseline || current);
        const parts = fieldKey.split(".");
        const value = controller.valueFor(current, fieldKey, parts.length === 1 ? item[fieldKey] : item[parts[0]][parts[1]]);
        snapshot = {item: item, key: fieldKey, value: controller.copy(value), childId: childId, childField: childField};
    }
    function save(value: var): void {
        const captured = snapshot;
        if (!session.active || !captured || controller.selectedItem?.id !== captured.item.id
            || controller.selectedItem?.kind !== captured.item.kind || !controller.canWrite(controller.selectedItem)) return;
        if (captured.childId) {
            const values = controller.copy(captured.value);
            const index = values.findIndex(child => child.id === captured.childId);
            if (index < 0) return;
            values[index][captured.childField] = value;
            value = values;
        }
        controller.saveFieldFor(captured.item, captured.key, value);
    }
    readonly property Connections lifecycle: Connections {
        target: transaction.session
        function onActiveChanged(): void { if (transaction.session.active) transaction.begin(); else transaction.snapshot = null; }
        function onFinished(saved: bool): void { transaction.snapshot = null; }
    }
    readonly property Connections targetChanges: Connections {
        target: transaction.controller
        function onSelectedSummaryChanged(): void {
            if (transaction.snapshot && transaction.controller.selectedSummary?.id !== transaction.snapshot.item.id) transaction.snapshot = null;
        }
    }
    Component.onCompleted: if (session.active) begin()
}
