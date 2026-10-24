import QtQuick
import Shelllist.Core as Core

Core.DraftStore {
    required property BluetoothController controller
    required property BluetoothBackend backend
    property string requestKey: ""
    readonly property var wireFields: ({
            alias: "alias",
            discoverableTimeout: "discoverable_timeout",
            pairableTimeout: "pairable_timeout"
        })

    function draft(key: var): var {
        return drafts[key] || { fields: {}, error: "", pending: false };
    }
    function edit(key: string, field: string, value: var): void {
        if (!key || draft(key).pending || !Object.prototype.hasOwnProperty.call(wireFields, field))
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
    // Normalize a complete saved draft atomically. Null means no safe patch;
    // this never modifies drafts, pending state or an acknowledged observation.
    function savedChanges(fields: var): var {
        const changes = ({});
        for (const field of Object.keys(fields)) {
            if (!Object.prototype.hasOwnProperty.call(wireFields, field)) return null;
            const value = field === "alias" ? String(fields[field]).trim() : Math.round(Number(fields[field]));
            if (field === "alias" ? !value : !Number.isFinite(value) || value < 0) return null;
            changes[wireFields[field]] = value;
        }
        return Object.keys(changes).length ? changes : null;
    }
    function saveBatch(key: string): bool {
        const current = draft(key);
        const adapter = controller.adapters.find(entry => entry.key === key);
        if (!adapter || !controller.backendAvailable || controller.globalRequestInFlight || current.error || current.pending)
            return false;
        const changes = savedChanges(current.fields);
        if (!changes) return false;
        // Only saved field values enter this immutable submission, never editor buffers.
        patch(key, { pending: true, pendingValues: changes });
        requestKey = key;
        if (backend.updateAdapter(key, changes))
            return true;
        requestKey = "";
        finish(key, null, "Could not send the adapter settings");
        return false;
    }
    function retry(key: string): bool {
        if (draft(key).pending || controller.globalRequestInFlight)
            return false;
        patch(key, { error: "" });
        return saveBatch(key);
    }
    function validBatch(key: string, batch: var, submitted: var): bool {
        if (!batch || batch.key !== key || !Array.isArray(batch.outcomes)
                || batch.outcomes.length !== Object.keys(submitted).length) return false;
        const seen = ({});
        return batch.outcomes.every(function (outcome) {
            if (!outcome || seen[outcome.field] || !Object.prototype.hasOwnProperty.call(submitted, outcome.field)
                    || outcome.value !== submitted[outcome.field]
                    || !["applied", "unknown", "not-attempted"].includes(outcome.state)) return false;
            seen[outcome.field] = true;
            return true;
        });
    }
    function finish(key: string, batch: var, error: string): string {
        const current = draft(key);
        if (!current.pending) return "";
        if (!error && !validBatch(key, batch, current.pendingValues))
            error = "Adapter outcome unconfirmed; inspect current settings before retrying";
        if (error) {
            patch(key, { pending: false, pendingValues: null, error: error });
            return error;
        }
        return acknowledgeBatch(key, current.fields, batch);
    }
    function acknowledgeBatch(key: string, submittedFields: var, batch: var): string {
        const outcomes = batch.outcomes;
        const fields = Object.assign({}, submittedFields);
        for (const field of Object.keys(fields)) {
            if (outcomes.some(outcome => outcome.field === wireFields[field] && outcome.state === "applied"))
                delete fields[field];
        }
        const remaining = Object.keys(fields).length > 0;
        const failed = outcomes.find(outcome => outcome.state === "unknown");
        const message = remaining
            ? "Adapter settings not fully confirmed; inspect current settings before retrying. " + (failed?.error?.message || "Some settings were not attempted")
            : "Bluetooth adapter settings updated";
        put(key, remaining ? { fields: fields, pending: false, error: message } : null);
        return batch.snapshot_error ? message + "; snapshot unavailable: " + (batch.snapshot_error.message || "Refresh required") : message;
    }
    function receive(data: var, error: string): void {
        const key = requestKey;
        requestKey = "";
        if (!key)
            return;
        let message = finish(key, data.adapter_batch, error);
        // Observations follow acknowledgement: a bad snapshot cannot undo a write.
        if (!error && data.snapshot) {
            try {
                controller.applySnapshot(data.snapshot);
            } catch (snapshotError) {
                message += "; could not read adapter snapshot: " + snapshotError;
            }
        }
        if (message)
            controller.status = message;
    }
    function transportFailed(message: string): void {
        requestKey = "";
        for (const key of Object.keys(drafts)) {
            if (draft(key).pending)
                finish(key, null, "Adapter outcome unknown; inspect current settings before retrying: " + message);
        }
    }
}
