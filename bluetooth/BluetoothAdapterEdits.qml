import QtQuick

Item {
    required property BluetoothController controller
    required property BluetoothBackend backend
    property var drafts: ({})
    readonly property var operations: ({alias: "set-alias", discoverableTimeout: "set-discoverable-timeout", pairableTimeout: "set-pairable-timeout"})

    function draft(key: string): var { return drafts[key] || {fields: {}, error: "", pendingField: ""}; }
    function put(key: string, value: var): void {
        const next = Object.assign({}, drafts);
        if (value)
            next[key] = value;
        else
            delete next[key];
        drafts = next;
    }
    function edit(key: string, field: string, value: var): void {
        if (!key || draft(key).pendingField)
            return;
        const fields = Object.assign({}, draft(key).fields, {[field]: value});
        put(key, {fields: fields, error: "", pendingField: ""});
    }
    function clearField(key: string, field: string): void {
        const current = draft(key);
        const fields = Object.assign({}, current.fields);
        delete fields[field];
        put(key, Object.keys(fields).length ? Object.assign({}, current, {fields: fields}) : null);
    }
    function discard(key: string): void {
        if (!draft(key).pendingField)
            put(key, null);
    }
    function saveNext(key: string): bool {
        const current = draft(key);
        const adapter = controller.adapters.find(function (entry) { return entry.key === key; });
        if (!adapter || !controller.backendAvailable || controller.globalRequestInFlight || current.error || current.pendingField)
            return false;
        const field = Object.keys(current.fields)[0];
        if (!field)
            return false;
        const value = field === "alias" ? String(current.fields[field]).trim() : Math.round(Number(current.fields[field]) || 0);
        if (field === "alias" && !value)
            return false;
        put(key, Object.assign({}, current, {pendingField: field, pendingValue: value}));
        const values = field === "alias" ? {alias: value} : {timeout: value};
        if (backend.adapterOperation(operations[field], adapter, values))
            return true;
        finish(key, operations[field], "Could not send the adapter setting");
        return false;
    }
    function retry(key: string): bool {
        const current = draft(key);
        if (current.pendingField)
            return false;
        put(key, Object.assign({}, current, {error: ""}));
        return saveNext(key);
    }
    function finish(key: string, operation: string, error: string): void {
        const current = draft(key);
        const field = current.pendingField;
        if (!field || operations[field] !== operation)
            return;
        if (error) {
            put(key, Object.assign({}, current, {pendingField: "", error: error}));
            return;
        }
        const fields = Object.assign({}, current.fields);
        delete fields[field];
        put(key, Object.keys(fields).length ? {fields: fields, error: "", pendingField: ""} : null);
        // Continue a submitted batch even if its editor has since been unloaded.
        Qt.callLater(saveNext, key);
    }
    function transportFailed(message: string): void {
        for (const key of Object.keys(drafts)) {
            const current = draft(key);
            if (current.pendingField)
                finish(key, operations[current.pendingField], message);
        }
    }
}
