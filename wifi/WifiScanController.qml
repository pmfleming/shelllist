import QtQuick
import "NmApiClient.js" as Api

Item {
    id: scan

    required property WifiController controller
    required property WifiBackend backend
    property bool pendingRefresh: false
    property bool snapshotSeen: false
    property string requestId: ""
    readonly property bool running: backend.listRunning || backend.scanRunning

    function activate() { refresh(); refreshTimer.restart(); }
    function deactivate() {
        pendingRefresh = false; backend.cancel(requestId); requestId = ""; snapshotSeen = false; refreshTimer.stop();
    }
    function refresh() {
        if (!controller.uiActive) { pendingRefresh = false; return; }
        if (controller.connection.running) {
            pendingRefresh = true;
            controller.setBackgroundStatus("Connection in progress; delaying Wi-Fi scan refresh…");
            return;
        }
        if (running) { pendingRefresh = true; controller.status = "Refresh already running; queued another refresh…"; return; }
        pendingRefresh = false;
        controller.setBackgroundStatus("Loading cached Wi-Fi networks…");
        snapshotSeen = false;
        backend.refreshNetworks(false); backend.startScan();
    }
    function maybeRefresh() {
        if (controller.uiActive && pendingRefresh && !controller.connection.running && !running) Qt.callLater(refresh);
    }
    function handleWatchdog() {
        if (!controller.uiActive || requestId.length === 0) return;
        backend.cancel(requestId); requestId = "";
        if (!snapshotSeen) {
            controller.status = "Wi-Fi scan events timed out; loading refreshed cache…";
            if (!backend.listRunning) backend.refreshNetworks(false);
        } else controller.setBackgroundStatus("Wi-Fi scan finished without a completion event.");
        maybeRefresh();
    }
    function applyEvent(event) {
        if (event.event === "snapshot") { snapshotSeen = true; controller.applyNetworks(event.networks || [], false); }
        controller.setBackgroundStatus(Api.scanEventStatus(event, controller.status));
    }
    function handleStream(event) {
        if (!controller.uiActive || !Api.requestMatches(event, requestId)) return;
        applyEvent(event);
        if (Api.isTerminalEvent(event)) { requestId = ""; maybeRefresh(); }
    }

    onRequestIdChanged: requestId.length > 0 ? watchdogTimer.restart() : watchdogTimer.stop()
    Timer { id: watchdogTimer; interval: 15000; repeat: false; onTriggered: scan.handleWatchdog() }
    Timer { id: refreshTimer; interval: 30000; repeat: true; onTriggered: scan.refresh() }
}
