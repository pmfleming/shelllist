import QtQuick

Item {
    id: edits
    required property BluetoothController controller
    required property BluetoothBackend backend
    property var drafts: ({})
    property var finishedRequests: []

    function draft(key: string): var { return drafts[key] || null; }
    function put(key: string, value: var): void {
        const next = Object.assign({}, drafts);
        if (value)
            next[key] = value;
        else
            delete next[key];
        drafts = next;
    }
    function edit(key: string, value: string): void {
        if (!key || (draft(key) || {}).pending)
            return;
        put(key, {value: value, dirty: true, pending: false, error: "", requestId: ""});
    }
    function save(key: string): bool {
        const current = draft(key);
        const device = controller.allDevices.find(function (entry) { return entry.key === key; });
        if (!current || !current.dirty || current.pending || current.error || !device
            || !controller.backendAvailable || controller.globalRequestInFlight || controller.screenshotInFlight || controller.deviceBusy(key))
            return false;
        const value = current.value.trim();
        if (!value || !(device.capabilities || {}).can_rename)
            return false;
        if (value === device.name) {
            put(key, null);
            return false;
        }
        put(key, {value: value, dirty: true, pending: true, error: "", requestId: ""});
        controller.status = "Renaming " + device.name + "…";
        if (backend.deviceOperation("set-alias", device, {alias: value}))
            return true;
        rejected(key, "Could not send the device rename");
        return false;
    }
    function retry(key: string): bool {
        const current = draft(key);
        if (!current || current.pending)
            return false;
        put(key, Object.assign({}, current, {error: ""}));
        return save(key);
    }
    function discard(key: string): void {
        if (!(draft(key) || {}).pending)
            put(key, null);
    }
    function rejected(key: string, message: string): void {
        const current = draft(key);
        if (current && current.pending)
            put(key, Object.assign({}, current, {pending: false, dirty: true, error: message, requestId: ""}));
    }
    function observe(operation: var): void {
        if (!operation || operation.operation !== "set-alias" || finishedRequests.includes(operation.request_id))
            return;
        if (!["queued", "running"].includes(operation.state))
            finishedRequests = finishedRequests.concat([operation.request_id]).slice(-128);
        const key = operation.device_key;
        const current = draft(key);
        if (!current || !current.pending || (current.requestId && current.requestId !== operation.request_id))
            return;
        if (operation.state === "queued" || operation.state === "running") {
            put(key, Object.assign({}, current, {requestId: operation.request_id}));
        } else if (operation.state === "completed") {
            put(key, null);
        } else {
            rejected(key, (operation.error || {}).message || "Device rename did not complete");
        }
    }
    function transportFailed(message: string): void {
        for (const key of Object.keys(drafts))
            rejected(key, message);
    }
}
