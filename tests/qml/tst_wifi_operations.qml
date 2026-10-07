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
            Wifi.WifiController {
                id: controller
                prompt: Wifi.WifiPromptController {}
            }
            Wifi.WifiContent { anchors.fill: parent; controller: panel.controller }
        }
    }
    function makePanel() {
        const panel = createTemporaryObject(panelFactory, testCase);
        verify(panel !== null);
        calls = [];
        return panel;
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
