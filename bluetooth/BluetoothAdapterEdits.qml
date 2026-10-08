import QtQuick
import Shelllist.Core as Core

Core.DraftStore {
    required property BluetoothController controller
    required property BluetoothBackend backend
    readonly property var wireFields: ({
            alias: "alias",
            discoverableTimeout: "discoverable_timeout",
            pairableTimeout: "pairable_timeout"
        })

    function draft(key: var): var {
        return drafts[key] || { fields: {}, error: "", pending: false };
    }
    function edit(key: string, field: string, value: var): void {
        if (!key || draft(key).pending || !wireFields[field])
            return;
        put(key, {
            fields: Object.assign({}, draft(key).fields, { [field]: value }),
            error: draft(key).error,
            pending: false
        });
    }
    function clearField(key: string, field: string): void {
        const current = draft(key);
        if (current.pending)
            return;
        const fields = Object.assign({}, current.fields);
        delete fields[field];
        put(key, Object.keys(fields).length ? Object.assign({}, current, { fields: fields }) : null);
    }
    function discard(key: string): void {
        if (!draft(key).pending)
            put(key, null);
    }
    function saveBatch(key: string): bool {
        const current = draft(key);
        const adapter = controller.adapters.find(entry => entry.key === key);
        if (!adapter || !controller.backendAvailable || controller.globalRequestInFlight || current.error || current.pending)
            return false;
        const fields = Object.keys(current.fields);
        if (!fields.length)
            return false;
        const changes = ({});
        for (const field of fields) {
            const value = field === "alias" ? String(current.fields[field]).trim() : Math.round(Number(current.fields[field]));
            if (!wireFields[field] || (field === "alias" ? !value : !Number.isFinite(value) || value < 0))
                return false;
            changes[wireFields[field]] = value;
        }
        // Only saved field values enter this immutable submission, never editor buffers.
        patch(key, { pending: true, pendingValues: changes });
        if (backend.updateAdapter(key, changes))
            return true;
        finish(key, null, "Could not send the adapter settings");
        return false;
    }
    function retry(key: string): bool {
        if (draft(key).pending || controller.globalRequestInFlight)
            return false;
        patch(key, { error: "" });
        return saveBatch(key);
    }
    function finish(key: string, batch: var, error: string): string {
        const current = draft(key);
        if (!current.pending)
            return "";
        const submitted = current.pendingValues;
        const outcomes = batch && batch.outcomes;
        if (!error) {
            const seen = ({});
            const valid = batch && batch.key === key && Array.isArray(outcomes)
                && outcomes.length === Object.keys(submitted).length
                && outcomes.every(function (outcome) {
                    if (!outcome || seen[outcome.field] || !Object.prototype.hasOwnProperty.call(submitted, outcome.field)
                        || outcome.value !== submitted[outcome.field]
                        || !["applied", "unknown", "not-attempted"].includes(outcome.state))
                        return false;
                    seen[outcome.field] = true;
                    return true;
                });
            if (!valid)
                error = "Adapter outcome unconfirmed; inspect current settings before retrying";
        }
        if (error) {
            patch(key, { pending: false, pendingValues: null, error: error });
            return error;
        }
        const fields = Object.assign({}, current.fields);
        for (const field of Object.keys(fields)) {
            if (outcomes.some(outcome => outcome.field === wireFields[field] && outcome.state === "applied"))
                delete fields[field];
        }
        const remaining = Object.keys(fields).length > 0;
        const failed = outcomes.find(outcome => outcome.state === "unknown");
        const message = remaining
            ? "Adapter settings not fully confirmed; inspect current settings before retrying. " + ((failed && failed.error && failed.error.message) || "Some settings were not attempted")
            : "Bluetooth adapter settings updated";
        put(key, remaining ? { fields: fields, pending: false, error: message } : null);
        return batch.snapshot_error ? message + "; snapshot unavailable: " + (batch.snapshot_error.message || "Refresh required") : message;
    }
    function transportFailed(message: string): void {
        for (const key of Object.keys(drafts)) {
            if (draft(key).pending)
                finish(key, null, "Adapter outcome unknown; inspect current settings before retrying: " + message);
        }
    }
}
