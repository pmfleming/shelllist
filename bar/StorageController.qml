import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: controller
    property var storageState: null
    property string errorText: ""
    property string viewTab: "usage"
    property bool awaitingState: false
    property alias backend: backend
    readonly property var snapshot: storageState ? storageState.snapshot : null
    readonly property var policy: storageState ? storageState.policy : null
    readonly property bool busy: !!storageState && !!storageState.busy
    readonly property bool canAct: backend.ready && !awaitingState && !busy
        && !backend.isPending("policy") && !backend.isPending("scan") && !backend.isPending("clean")
    readonly property var viewTabs: [
        {value: "usage", label: qsTr("Usage"), icon: "storage"},
        {value: "cleanup", label: qsTr("Cleanup"), icon: "cleaning_services"},
        {value: "policy", label: qsTr("Policy"), icon: "settings"},
        {value: "history", label: qsTr("History"), icon: "history"}
    ]
    readonly property double eligibleBytes: snapshot ? snapshot.candidates.reduce((n, c) => n + (c.eligible ? c.bytes : 0), 0) : 0
    readonly property var rows: viewTab === "usage" ? (snapshot ? snapshot.usage : [])
        : viewTab === "cleanup" ? (snapshot ? snapshot.candidates : [])
        : viewTab === "history" ? (storageState ? storageState.history : []) : []
    expandable: false
    viewMemory: Ui.ChooserMemory { controller: controller; key: "storage"; tab: controller.viewTab; tabs: controller.viewTabs.map(t => t.value) }
    function cycleDetailsTab(backwards: bool): void { viewTab = tabAfter(viewTabs.map(t => t.value), viewTab, backwards); }
    function bytes(value: real): string { return (Number(value || 0) / (1024 * 1024 * 1024)).toFixed(2) + " GiB"; }
    function refresh(): void { if (backend.ready && !backend.requestRunning) backend.call("state", "storage.getState", {}); }
    function scan(): void { if (canAct) backend.call("scan", "storage.scan", {}); }
    function clean(): void { if (canAct && snapshot && eligibleBytes > 0) backend.call("clean", "storage.clean", {revision: snapshot.revision}); }
    function cancel(): void { if (backend.ready && busy) backend.call("cancel", "storage.cancel", {}); }
    function savePolicy(key: string, value: var): void {
        if (canAct && policy && JSON.stringify(policy[key]) !== JSON.stringify(value))
            backend.call("policy", "storage.setPolicy", Object.assign({}, policy, {[key]: value}));
    }
    function receive(id: string, envelope: var, transportError: string): void {
        const error = backend.responseError(envelope, transportError, qsTr("Storage request failed"));
        if (error) { awaitingState = false; errorText = error; return; }
        if (id === "state") {
            const data = envelope.data;
            if (snapshot && data.snapshot && snapshot.revision === data.snapshot.revision) data.snapshot = snapshot;
            storageState = data;
            awaitingState = false;
            errorText = storageState.error || "";
        } else { awaitingState = true; Qt.callLater(refresh); }
    }
    Io.DaemonBackend {
        id: backend
        daemonName: "storage-daemon"
        expectedProtocol: "storage-api"
        expectedVersion: 1
        active: controller.uiActive
        onTransportReady: controller.refresh()
        onResponseReceived: function(id, envelope, error) { controller.receive(id, envelope, error); }
        onTransportFailed: function(message) { controller.awaitingState = false; controller.errorText = message; }
        onSendFailed: function(id, message) { controller.awaitingState = false; controller.errorText = message; }
    }
    Connections { target: controller; function onUiActiveChanged(): void { if (controller.uiActive) controller.refresh(); } }
    Timer { interval: controller.busy ? 1000 : 10000; repeat: true; running: controller.uiActive; onTriggered: controller.refresh() }
}
