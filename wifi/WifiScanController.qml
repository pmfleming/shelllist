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
        pendingRefresh = false;
        if (requestId.length > 0 && !backend.cancel(requestId))
            console.warn("shelllist wifi scan cancellation failed request_id=" + requestId);
        requestId = ""; snapshotSeen = false; refreshTimer.stop();
    }
    function cancelForPowerOff() {
        pendingRefresh = false;
        if (requestId.length > 0 && !backend.cancel(requestId))
            console.warn("shelllist wifi scan cancellation failed request_id=" + requestId);
        requestId = "";
        snapshotSeen = false;
    }
    function handleTransportFailure() {
        const lostRequestId = requestId;
        requestId = "";
        snapshotSeen = false;
        pendingRefresh = controller.uiActive;
        if (lostRequestId.length > 0)
            console.warn("shelllist wifi scan discarded reason=transport-failure request_id=" + lostRequestId);
    }
    function refresh() {
        if (!controller.uiActive) { pendingRefresh = false; return; }
        if (!controller.powered) {
            pendingRefresh = false;
            controller.status = "Wi-Fi is off";
            return;
        }
        if (controller.connection.running) {
            pendingRefresh = true;
            controller.setBackgroundStatus("Connection in progress; delaying Wi-Fi scan refresh…");
            return;
        }
        if (running) { pendingRefresh = true; controller.status = "Refresh already running; queued another refresh…"; return; }
        pendingRefresh = false;
        controller.setBackgroundStatus("Loading cached Wi-Fi networks…");
        snapshotSeen = false;
        // The explicit scan below owns this refresh. Asking wifi.networks to
        // refresh its cache as well would schedule a second NetworkManager scan.
        const listAccepted = backend.refreshNetworks(false);
        const scanAccepted = backend.startScan();
        if (!listAccepted || !scanAccepted) {
            pendingRefresh = true;
            console.warn("shelllist wifi refresh partially dispatched networks=" + listAccepted + " scan=" + scanAccepted);
        }
    }
    function maybeRefresh() {
        if (controller.uiActive && controller.powered && pendingRefresh && !controller.connection.running && !running) Qt.callLater(refresh);
    }
    function handleWatchdog() {
        if (!controller.uiActive || requestId.length === 0) return;
        if (!backend.cancel(requestId))
            console.warn("shelllist wifi scan watchdog cancellation failed request_id=" + requestId);
        requestId = "";
        if (!snapshotSeen) {
            // The event stream is unavailable, so do not schedule a background
            // cache refresh whose completion would arrive over that same stream.
            // Read NetworkManager's current AP table through the request/reply path.
            controller.status = "Wi-Fi scan events timed out; loading current NetworkManager results…";
            if (!backend.listRunning && !backend.loadCurrentNetworks())
                console.warn("shelllist wifi live network load rejected after scan watchdog");
        } else controller.setBackgroundStatus("Wi-Fi scan finished without a completion event.");
        maybeRefresh();
    }
    function applyEvent(event) {
        if (event.event === "snapshot") {
            snapshotSeen = true;
            controller.applyNetworks(event.networks || [], false, event.snapshot || null);
        }
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
