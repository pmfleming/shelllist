import QtQuick

// Nested action arrays must stay JSON, not be converted to QQmlListModels.
// Reuse keyed reconciliation, but never reset/chunk a live reply editor away.
KeyedListModel {
    property var rows: []
    values: rows.map(row => ({
                key: row.key,
                payload: JSON.stringify(row.payload)
            }))

    function equivalent(left: var, right: var): bool {
        return left.payload === right.payload;
    }

    function sync(): void {
        reconcile(currentKeys());
    }
}
