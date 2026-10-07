pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Wifi as Wifi

DaemonTestCase {
    id: testCase
    name: "WifiOperations"
    when: windowShown
    visible: true
    width: 1100
    height: 760

    Component {
        id: panelFactory
        Item {
            id: panel
            width: testCase.width; height: testCase.height
            property alias controller: controller
            property alias page: page
            property alias scanner: scanner
            Wifi.WifiController {
                id: controller
                prompt: Wifi.WifiPromptController {}
            }
            Wifi.WifiContent { id: page; anchors.fill: parent; controller: panel.controller }
            QtObject {
                id: scanner
                property bool running: false
                property int launches: 0
                function exec(args) { launches++; running = true; }
            }
        }
    }
    function makePanel() {
        const panel = createTemporaryObject(panelFactory, testCase);
        verify(panel !== null);
        calls = [];
        panel.controller.qr.scannerExecutor = panel.scanner;
        return panel;
    }
    function openNetwork(panel, active) {
        const c = panel.controller;
        c.uiActive = true;
        c.applyNetworks([{key: "cafe", ssid: "Cafe", active: active, strength: 70, security: "Open", capabilities: {can_connect: true}}], true, {});
        tryVerify(function () { return panel.page.listItem !== null; });
        c.backend.pending = ({});
        calls = [];
        panel.page.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryCompare(c, "detailsOpen", true);
        tryVerify(function () { return panel.page.detailsNavigation.commandButtons.some(function (button) { return button.accessKey === (active ? "D" : "C") && button.enabled; }); });
        panel.page.listItem.focusList();
    }
    function test_keyboardRecoveryAndCancellationSurviveLinkBecomingActive() {
        const panel = makePanel();
        openNetwork(panel, true);
        const c = panel.controller;
        c.connection.networkKey = "cafe";
        c.connection.networkName = "Cafe";
        c.connection.requestId = "connect-owned";
        tryVerify(function () { return panel.page.detailsNavigation.commandButtons.some(function (button) { return button.accessKey === "K"; }); });
        keyClick(Qt.Key_K, Qt.AltModifier);
        compare(calls.slice(-1)[0].method, "operation.status");
        statusReply(c, {request_id: "connect-owned", status: "running", stream: "wifi.connect", event: {request_id: "connect-owned", event: "progress", message: "Verifying Wi-Fi activation"}});
        compare(c.status, "Verifying Wi-Fi activation");
        keyClick(Qt.Key_X, Qt.AltModifier);
        verify(c.connection.cancellationRequested, "active link must not hide pending cancellation");
        verify(c.actionInFlight, "cancel dispatch is not acknowledgement");
        c.connection.handleEvent({request_id: "connect-owned", event: "cancelled"});
        verify(!c.actionInFlight);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(calls.slice(-1)[0].method, "wifi.disconnect");
        verify(c.actionInFlight);
    }
    function test_qrAndRefreshKeyboardRoutesRemainAvailableDuringSlowConnect() {
        const panel = makePanel();
        openNetwork(panel, false);
        const c = panel.controller;
        c.connection.requestId = "connect-qr"; // no list key, as for a QR join
        panel.page.listItem.focusSearch();
        keyClick(Qt.Key_Return, Qt.AltModifier);
        compare(panel.scanner.launches, 1);
        verify(!findChild(panel, "fieldTrailingAction").enabled, "duplicate scanner launch is blocked");
        panel.scanner.running = false;
        mouseClick(findChild(panel, "fieldTrailingAction"));
        compare(panel.scanner.launches, 2);
        panel.page.listItem.focusSearch();
        keyClick(Qt.Key_F5);
        verify(c.scan.pendingRefresh);
        verify(!calls.some(function (call) { return call.method === "wifi.scan"; }));
        panel.page.listItem.focusList();
        keyClick(Qt.Key_X, Qt.AltModifier);
        verify(c.connection.cancellationRequested, "QR operation retains global cancel command");
    }
    function test_disconnectReplyAndFailureKeepControlsVisibleAndRetryable_data() {
        return [{tag: "success", ok: true}, {tag: "failure", ok: false}];
    }
    function test_disconnectReplyAndFailureKeepControlsVisibleAndRetryable(data) {
        const panel = makePanel();
        openNetwork(panel, true);
        const c = panel.controller;
        keyClick(Qt.Key_D, Qt.AltModifier);
        verify(c.backend.isPending("disconnect"));
        for (const name of ["fieldTrailingAction", "chooserRefreshButton", "chooserPowerToggle"])
            verify(findChild(panel, name).visible);
        const before = calls.length;
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(calls.length, before, "repeated mutation is blocked");
        c.backend.acceptSharedResponse("disconnect", {protocol: "nm-api", version: 1, ok: data.ok, data: {result: {message: "Disconnected Wi-Fi"}}, error: {code: "failed", message: "Disconnect failed"}}, "");
        verify(!c.actionInFlight);
        verify(findChild(panel, "chooserPowerToggle").enabled);
        if (!data.ok) {
            verify(c.status.indexOf("Disconnect failed") >= 0);
            panel.page.listItem.focusList();
            keyClick(Qt.Key_D, Qt.AltModifier);
            verify(c.backend.isPending("disconnect"), "explicit retry remains available");
        }
    }
    function test_readRequestsDoNotLockMutations_data() {
        return ["band-status", "status-recovery", "advanced-load", "inventory", "vpn-status", "portal-claim-1"].map(function (id) { return {tag: id, id: id}; });
    }
    function test_readRequestsDoNotLockMutations(data) {
        const panel = makePanel();
        panel.controller.backend.setPending(data.id, true);
        verify(!panel.controller.actionInFlight);
        verify(findChild(panel, "chooserPowerToggle").enabled);
    }
    function test_conflictingMutationsStayGuarded_data() {
        return ["disconnect", "power", "profile", "advanced-save", "qr-connect", "future-mutation"].map(function (id) { return {tag: id, id: id}; });
    }
    function test_conflictingMutationsStayGuarded(data) {
        const panel = makePanel();
        panel.controller.backend.setPending(data.id, true);
        verify(panel.controller.actionInFlight);
        const power = findChild(panel, "chooserPowerToggle");
        verify(power.visible);
        verify(!power.enabled);
        mouseClick(power);
        compare(calls.length, 0);
        verify(findChild(panel, "fieldTrailingAction").enabled);
        verify(findChild(panel, "chooserRefreshButton").enabled);
    }
    function statusReply(c, result, id) {
        c.backend.acceptSharedResponse(id || c.connection.recoveryId, {protocol: "nm-api", version: 1, ok: true, data: {result: result}}, "");
    }
    function test_missedCompletionIsRecoveredWithoutReplayingMutation() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.handleDaemonEventGap("wifi.connect");
        const read = calls.filter(function (call) { return call.method === "operation.status"; });
        compare(read.length, 1);
        compare(read[0].params.request_id, "connect-owned");
        statusReply(c, {request_id: "connect-owned", status: "finished", stream: "wifi.connect", event: {request_id: "connect-owned", event: "succeeded", result: {status: "connected", message: "Link connected; internet unknown"}}});
        compare(c.connection.requestId, "");
        verify(!c.actionInFlight);
        compare(c.status, "Link connected; internet unknown");
        compare(calls.filter(function (call) { return call.method === "wifi.connectTarget"; }).length, 0);
    }
    function test_slowOperationKeepsGuardUntilCancellationAcknowledgement() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.connection.checkStatus(true);
        statusReply(c, {request_id: "connect-owned", status: "running", stream: "wifi.connect", timed_out: true, cancellation_requested: true});
        verify(c.actionInFlight);
        verify(c.status.indexOf("timed out") >= 0);
        c.connection.handleEvent({request_id: "other", event: "cancelled"});
        verify(c.actionInFlight);
        c.connection.handleEvent({request_id: "connect-owned", event: "cancelled"});
        verify(!c.actionInFlight);
    }
    function test_statusFailuresAndLateRepliesCannotUnlockOrRetireNewRead() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.connection.checkStatus(true);
        const oldId = c.connection.recoveryId;
        c.connection.recoveryFailed("Read timed out.");
        verify(c.actionInFlight);
        verify(!c.backend.isPending(oldId));
        c.connection.checkStatus(true);
        const newId = c.connection.recoveryId;
        statusReply(c, {request_id: "connect-owned", status: "finished", stream: "wifi.connect", event: {request_id: "connect-owned", event: "cancelled"}}, oldId);
        compare(c.connection.recoveryId, newId);
        statusReply(c, {request_id: "different", status: "unknown"});
        verify(c.actionInFlight);
        compare(c.connection.recoveryId, "");
        verify(c.connection.checkStatus(true), "manual read retry stays available");
    }
    function test_backgroundReadsDoNotReplaceForegroundProgress() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.status = "Verifying Wi-Fi activation";
        c.setBackgroundStatus("12 cached networks");
        compare(c.status, "Verifying Wi-Fi activation");
        c.connection.requestId = "";
        c.setBackgroundStatus("12 cached networks");
        compare(c.status, "12 cached networks");
    }
    function test_daemonStatusMakesUnacknowledgedCancellationRetryable() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.connection.cancel();
        verify(c.connection.cancellationRequested);
        c.connection.checkStatus(true);
        statusReply(c, {request_id: "connect-owned", stream: "wifi.connect", status: "running", cancellation_requested: false});
        verify(!c.connection.cancellationRequested);
        verify(c.actionInFlight);
    }
    function test_recoveryTimersAreBoundedAndManualRetryRemainsAvailable() {
        const panel = makePanel();
        const c = panel.controller;
        const poll = findChild(c.connection, "connectionRecoveryPoll");
        const deadline = findChild(c.connection, "connectionRecoveryReplyDeadline");
        poll.interval = 5;
        deadline.interval = 5;
        c.connection.requestId = "connect-owned";
        tryCompare(c.connection, "recoveryFailures", 3);
        verify(!poll.running);
        verify(!deadline.running);
        verify(c.actionInFlight);
        compare(calls.filter(function (call) { return call.method === "operation.status"; }).length, 3);
        deadline.interval = 10000;
        verify(c.connection.checkStatus(true));
        compare(c.connection.recoveryFailures, 0);
        c.connection.handleEvent({request_id: "connect-owned", event: "cancelled"});
        verify(!poll.running && !deadline.running);
    }
    function test_malformedOrUnknownRecoveryNeverClaimsCompletion_data() {
        return [
            {tag: "missing", result: null},
            {tag: "unknown", result: {request_id: "connect-owned", status: "unknown"}},
            {tag: "foreign-stream", result: {request_id: "connect-owned", status: "running", stream: "vpn"}},
            {tag: "missing-terminal", result: {request_id: "connect-owned", status: "finished", stream: "wifi.connect"}},
            {tag: "foreign-terminal", result: {request_id: "connect-owned", status: "finished", stream: "wifi.connect", event: {request_id: "other", event: "succeeded"}}}
        ];
    }
    function test_malformedOrUnknownRecoveryNeverClaimsCompletion(data) {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.connection.checkStatus(true);
        statusReply(c, data.result);
        compare(c.connection.requestId, "connect-owned");
        verify(c.actionInFlight);
        compare(c.connection.recoveryId, "");
        verify(c.status.indexOf("unconfirmed") >= 0);
    }
    function test_transportFailureStopsRecoveryAndNeverReplaysConnection() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.connection.checkStatus(true);
        const oldRead = c.connection.recoveryId;
        c.backend.failSharedTransport("Lost daemon");
        compare(c.connection.recoveryId, "");
        compare(c.connection.requestId, "");
        c.backend.handleTransportReady();
        statusReply(c, {request_id: "connect-owned", status: "finished", stream: "wifi.connect", event: {request_id: "connect-owned", event: "succeeded"}}, oldRead);
        verify(c.status.indexOf("Lost daemon") >= 0);
        verify(!calls.some(function (call) { return call.method === "wifi.connectTarget" || call.method === "wifi.qr.connect"; }));
    }
    function test_screenshotAndConnectionAreIndependent() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        c.connection.requestId = "connect-owned";
        verify(c.captureScreenshot(0, 0, 100, 100));
        verify(c.screenshotInFlight);
        verify(findChild(panel, "fieldTrailingAction").enabled);
        c.connection.requestId = "";
        verify(!c.actionInFlight, "capture alone cannot disable network changes");
        verify(findChild(panel, "chooserPowerToggle").enabled);
        verify(!c.captureScreenshot(0, 0, 100, 100), "duplicate captures remain guarded");
    }
    function test_qrDuringConnectOnlyParsesAndNeverRetainsCredentials() {
        const panel = makePanel();
        const c = panel.controller;
        c.connection.requestId = "connect-owned";
        verify(findChild(panel, "fieldTrailingAction").enabled);
        verify(c.joinScannedQr("WIFI:T:WPA;S:Example;P:secret;;"));
        compare(calls.slice(-1)[0].method, "wifi.qr.parse");
        compare(c.qr.payload, "");
        verify(!c.connection.canBeginAny());
        c.backend.setPending("qr-parse", false);
        c.connection.requestId = "";
        verify(c.joinScannedQr("WIFI:T:WPA;S:Example;P:secret;;"));
        compare(calls.slice(-1)[0].method, "wifi.qr.connect");
        verify(c.backend.connectStarting);
    }
}
