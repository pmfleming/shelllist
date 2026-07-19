import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property bool detailsOpen: false
    property bool scanRequested: false
    property var adapters: []
    property string status: "Loading Bluetooth devices…"
    readonly property bool actionInFlight: backend.running
    readonly property var filteredResults: results.visibleResults
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property bool powered: adapters.some(function (adapter) { return adapter.powered; })
    readonly property bool scanning: adapters.some(function (adapter) { return adapter.discovering; })
    readonly property int closedWindowWidth: 440
    readonly property int openWindowWidth: 820
    property int surfaceWindowWidth: detailsOpen ? openWindowWidth : closedWindowWidth

    signal closeWindowRequested
    signal focusSearchRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        scanRequested = false;
        refresh();
        refreshTimer.start();
    }
    function deactivateUi() {
        refreshTimer.stop();
        scanRequested = false;
        backend.setScanning(false);
        uiActive = false;
    }
    function refresh() {
        status = scanning ? "Scanning for Bluetooth devices…" : "Refreshing Bluetooth devices…";
        backend.refresh();
    }
    function applySnapshot(snapshot) {
        adapters = snapshot.adapters || [];
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(snapshot.devices || []), false);
        if (uiActive && powered && !scanning && !scanRequested) {
            scanRequested = true;
            backend.setScanning(true);
        }
        if (!powered)
            status = "Bluetooth is off";
        else if (scanning)
            status = filteredResults.length + " devices · scanning…";
        else
            status = filteredResults.length + " Bluetooth devices";
    }
    function statusForCompletedCall(id) {
        if (id === "power")
            return powered ? "Bluetooth turned on" : "Bluetooth turned off";
        if (id === "scan-start")
            return "Scanning for Bluetooth devices…";
        if (id === "scan-stop")
            return "Bluetooth scan stopped";
        if (id.indexOf("device-") === 0)
            return "Bluetooth device updated";
        return status;
    }
    function setPower() {
        status = powered ? "Turning Bluetooth off…" : "Turning Bluetooth on…";
        scanRequested = false;
        backend.setPowered(!powered);
    }
    function toggleScan() {
        status = scanning ? "Stopping Bluetooth scan…" : "Scanning for Bluetooth devices…";
        scanRequested = true;
        backend.setScanning(!scanning);
    }
    function moveSelection(delta) { results.move(delta); }
    function primarySelected() { return hasSelection && providers.execute(selectedResult, "", { workspaceId: currentWorkspaceId }); }
    function triggerAction(id) { return hasSelection && providers.execute(selectedResult, id, { workspaceId: currentWorkspaceId }); }
    function executeDeviceAction(actionId, device) {
        if (actionInFlight)
            return false;
        const operation = ({ pair: "pair", connect: "connect", disconnect: "disconnect", remove: "remove" })[actionId];
        if (operation) {
            status = operation.charAt(0).toUpperCase() + operation.slice(1) + " " + device.name + "…";
            return backend.deviceOperation(operation, device, {});
        }
        if (actionId === "trusted")
            return backend.deviceOperation("set-trusted", device, { trusted: !device.trusted });
        if (actionId === "wake")
            return backend.deviceOperation("set-wake-allowed", device, { wake_allowed: !device.wake_allowed });
        if (actionId === "blocked")
            return backend.deviceOperation("set-blocked", device, { blocked: !device.blocked });
        return false;
    }

    Timer { id: refreshTimer; interval: 1500; repeat: true; onTriggered: backend.refresh() }
    Behavior on surfaceWindowWidth { enabled: !Ui.Theme.noAnimations; NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
    Core.ProviderRegistry {
        id: providers
        BluetoothProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    BluetoothBackend { id: backend; controller: controller }
}
