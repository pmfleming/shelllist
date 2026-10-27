import QtQuick
import "BluetoothFlow.js" as BluetoothFlow

Item {
    required property BluetoothController controller
    required property BluetoothBackend backend
    property var activeOperations: ({})
    property var errorsByDevice: ({})

    function copyWith(values: var, key: string, value: var): var {
        const result = Object.assign({}, values || ({}));
        result[key] = value;
        return result;
    }
    function copyWithout(values: var, key: string): var {
        const result = Object.assign({}, values || ({}));
        delete result[key];
        return result;
    }
    function reset(): void {
        activeOperations = ({});
        errorsByDevice = ({});
    }
    function forDevice(deviceKey: string): var {
        if (!deviceKey)
            return null;
        return Object.values(activeOperations).find(operation => operation.device_key === deviceKey) || null;
    }
    function errorForDevice(deviceKey: string): var {
        return deviceKey ? (errorsByDevice[deviceKey] || null) : null;
    }
    function accept(operation: var): void {
        if (!operation || !operation.request_id)
            return;
        if (!activeOperations[operation.request_id])
            activeOperations = copyWith(activeOperations, operation.request_id, operation);
        errorsByDevice = copyWithout(errorsByDevice, operation.device_key);
        controller.rebuildResults(false);
    }
    function unknown(operation: var, message: string): void {
        // Keep the device busy: uncertainty is not proof the accepted effect stopped.
        activeOperations = copyWith(activeOperations, operation.request_id,
            Object.assign({}, operation, {state: "unknown"}));
        errorsByDevice = copyWith(errorsByDevice, operation.device_key, {message: message});
        controller.status = message;
        controller.rebuildResults(false);
    }
    function applyActive(operation: var, deviceName: string): void {
        activeOperations = copyWith(activeOperations, operation.request_id, operation);
        errorsByDevice = copyWithout(errorsByDevice, operation.device_key);
        controller.status = BluetoothFlow.activeOperationStatus(operation, deviceName);
        controller.rebuildResults(false);
    }
    function applyCompleted(operation: var, recovered: var): void {
        activeOperations = copyWithout(activeOperations, operation.request_id);
        errorsByDevice = operation.state === "failed" ? copyWith(errorsByDevice, operation.device_key, operation.error || ({
                message: "Bluetooth operation failed"
            })) : copyWithout(errorsByDevice, operation.device_key);
        controller.rebuildResults(false);
        // Completion acknowledges the operation, not an ordering watermark on
        // its embedded observation. Never replace a newer watch with that data.
        // A recovered outcome must not indirectly run snapshot-driven scan
        // policy either. Radio recovery has its own authoritative read/watch.
        if (!recovered)
            backend.reconcileSnapshot();
    }
    function resumeScan(operation: var, device: var): void {
        if (!BluetoothFlow.shouldRescanAfterOperation(operation, controller.uiActive && controller.searchAllDevices, controller.powered, controller.scanning))
            return;
        controller.scanRequested = true;
        backend.setScanning(true, operation.adapter_key || device.adapter_key || controller.selectedAdapter.key);
    }
    function handle(operation: var, recovered: var): void {
        if (!operation || !operation.request_id)
            return;
        const device = controller.allDevices.find(function (candidate) {
            return candidate.key === operation.device_key;
        }) || ({});
        const deviceName = device.name || "Bluetooth device";
        if (BluetoothFlow.isActiveOperation(operation)) {
            applyActive(operation, deviceName);
            return;
        }
        applyCompleted(operation, recovered);
        controller.status = BluetoothFlow.operationCompletionStatus(operation, deviceName);
        // Neither live nor recovered operation outcomes identify a pairing
        // prompt. Only prompt-ID lifecycle/response handling may clear its draft.
        if (!recovered)
            resumeScan(operation, device);
    }
}
