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
