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
    function reset(): void { activeOperations = ({}); errorsByDevice = ({}); }
    function restore(operations: var): void {
        const next = ({});
        (operations || []).forEach(function (operation) {
            if (operation && operation.request_id
                    && BluetoothFlow.isActiveOperation(operation))
                next[operation.request_id] = operation;
        });
        activeOperations = next;
        controller.rebuildResults(false);
    }
    function forDevice(deviceKey: string): var {
        if (!deviceKey)
            return null;
        const requestIds = Object.keys(activeOperations);
        for (let index = 0; index < requestIds.length; index++) {
            const operation = activeOperations[requestIds[index]];
            if (operation.device_key === deviceKey)
                return operation;
        }
        return null;
    }
    function errorForDevice(deviceKey: string): var { return deviceKey ? (errorsByDevice[deviceKey] || null) : null; }
    function accept(operation: var): void {
        if (!operation || !operation.request_id)
            return;
        if (!activeOperations[operation.request_id])
            activeOperations = copyWith(activeOperations, operation.request_id, operation);
        errorsByDevice = copyWithout(errorsByDevice, operation.device_key);
        controller.rebuildResults(false);
    }
    function applyActive(operation: var, deviceName: string): void {
        activeOperations = copyWith(activeOperations, operation.request_id, operation);
        errorsByDevice = copyWithout(errorsByDevice, operation.device_key);
        controller.status = BluetoothFlow.activeOperationStatus(operation, deviceName);
        controller.rebuildResults(false);
    }
    function applyCompleted(operation: var): void {
        activeOperations = copyWithout(activeOperations, operation.request_id);
        errorsByDevice = operation.state === "failed"
            ? copyWith(errorsByDevice, operation.device_key,
                operation.error || ({ message: "Bluetooth operation failed" }))
            : copyWithout(errorsByDevice, operation.device_key);
        if (operation.snapshot)
            controller.applySnapshot(operation.snapshot);
        else
            controller.rebuildResults(false);
    }
    function closePairing(operation: var): void {
        if (!controller.pairingPrompt || controller.pairingPrompt.device_key !== operation.device_key)
            return;
        controller.pairingPrompt = null;
        controller.pairingInput = "";
    }
    function resumeScan(operation: var, device: var): void {
        if (!BluetoothFlow.shouldRescanAfterOperation(operation,
                controller.uiActive && controller.searchAllDevices,
                controller.powered, controller.scanning))
            return;
        controller.scanRequested = true;
        backend.setScanning(true,
            operation.adapter_key || device.adapter_key || controller.selectedAdapter.key);
    }
    function handle(operation: var): void {
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
        applyCompleted(operation);
        controller.status = BluetoothFlow.operationCompletionStatus(operation, deviceName);
        closePairing(operation);
        resumeScan(operation, device);
    }
}
