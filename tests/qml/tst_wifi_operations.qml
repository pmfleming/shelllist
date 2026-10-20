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
        statusReply(c, {request_id: "connect-owned", status: "running", stream: "wifi.connect", event: {request_id: "connect-owned", event: "progress", data: {message: "Verifying Wi-Fi activation"}}});
        compare(c.status, "Verifying Wi-Fi activation");
        keyClick(Qt.Key_X, Qt.AltModifier);
        verify(c.connection.cancellationRequested, "active link must not hide pending cancellation");
        verify(c.actionInFlight, "cancel dispatch is not acknowledgement");
        c.connection.handleEvent({request_id: "other", event: "cancelled", data: {}});
        verify(c.actionInFlight, "foreign cancellation cannot release the guard");
        c.connection.handleEvent({request_id: "connect-owned", event: "cancelled", data: {}});
        verify(!c.actionInFlight);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(calls.slice(-1)[0].method, "wifi.disconnect");
        verify(c.actionInFlight);
    }
    function savedNetwork(panel) {
        openNetwork(panel, false);
        panel.controller.applyNetworks([{key: "cafe", ssid: "Cafe", active: false, strength: 70,
            security: "WPA2", security_class: "personal", capabilities: {can_connect: true},
            primary_profile: {path: "/profile/cafe", id: "Cafe"},
            connect_prompt: {kind: "password", message: "Stale initial descriptor"}
        }], true, {});
        calls = [];
    }
    function test_savedConnectButtonActivatesWithoutCollectingOrReplacingCredentials_data() {
        return ["secret-required"].map(outcome => ({tag: outcome, outcome: outcome}));
    }
    function test_savedConnectButtonActivatesWithoutCollectingOrReplacingCredentials(data) {
        const panel = makePanel();
        savedNetwork(panel);
        const c = panel.controller;
        const button = panel.page.detailsNavigation.commandButtons.find(button => button.accessKey === "C");
        verify(!!button && button.enabled);
        mouseClick(button);
        const request = calls.find(call => call.method === "wifi.connectTarget");
        verify(!!request);
        compare(request.params.key, "cafe");
        verify(!request.params.password);
        verify(!c.prompt.open && !c.prompt.credentialOpen);
        c.backend.acceptSharedResponse("connect-start", {protocol: "nm-api", version: 2, ok: true,
            data: {result: {status: "started", request_id: "clicked-connect"}}}, "");
        compare(c.connection.requestId, "clicked-connect");
        if (data.outcome === "secret-required") {
            c.handleSecretEvent({event: "requested", request_id: "clicked-secret", data: {secret_keys: ["psk"], timeout_ms: 60000}});
            verify(c.prompt.credentialOpen, "only NetworkManager's live request collects credentials");
        }
        const terminal = ["cancelled", "succeeded"].includes(data.outcome) ? data.outcome : "failed";
        c.connection.handleEvent({request_id: "clicked-connect", event: terminal, data: {
            message: "Native " + data.outcome, result: {
                status: terminal === "succeeded" ? "connected" : "error", reason: data.outcome,
                message: "Native " + data.outcome,
                recovery_prompt: {kind: "password", message: "Recovery is explicit"}
            }
        }});
        if (data.outcome === "secret-required") {
            c.handleSecretEvent({event: "cancelled", request_id: "clicked-secret", data: {reason: "activation-finished"}});
            compare(c.status, "Native secret-required", "prompt retirement preserves the terminal failure");
        }
        verify(!c.prompt.open && !c.prompt.credentialOpen);
        compare(calls.filter(call => call.method === "wifi.connectTarget").length, 1);
    }
    function profileReply(panel) {
        panel.controller.backend.acceptSharedResponse("advanced-load", {protocol: "nm-api", version: 2, ok: true, data: {result: {
            path: "/profile/cafe", version: "test-version", security_type: "WPA2 Personal",
            ipv4: {method: "auto"}, ipv6: {method: "auto"}
        }}}, "");
    }
    function openPasswordEditor(panel) {
        savedNetwork(panel);
        const c = panel.controller;
        c.advanced.openSettings("security");
        profileReply(panel);
        let field = null;
        tryVerify(function () {
            field = panel.page.detailsNavigation.availableFields().find(item => item.sensitive);
            return !!field;
        });
        return field;
    }
    function secretReply(panel) {
        panel.controller.backend.acceptSharedResponse("advanced-secret", {protocol: "nm-api", version: 2, ok: true,
            data: {result: {path: "/profile/cafe", available: true, password: "synthetic-password"}}}, "");
    }
    function test_passwordReadFailureCanRetryAndForeignReplyCannotReveal() {
        const panel = makePanel();
        const field = openPasswordEditor(panel);
        field.focusInput(false);
        mouseClick(field.trailingAction);
        panel.controller.backend.acceptSharedResponse("advanced-secret", {protocol: "nm-api", version: 2, ok: true,
            data: {result: {path: "/profile/cafe", available: false}}}, "");
        compare(field.text, "");
        verify(field.password);
        verify(panel.controller.advanced.error.length > 0);
        mouseClick(field.trailingAction);
        secretReply(panel);
        compare(field.text, "synthetic-password");
        keyClick(Qt.Key_Escape);
        panel.controller.advanced.applyProfile(Object.assign({}, panel.controller.advanced.profile));
        panel.controller.advanced.applySecret({path: "/profile/other", available: true, password: "foreign-secret"});
        compare(field.text, "");
        verify(field.password);
    }
    function test_credentialTimerClearsDraftAndIgnoresLateReceipt() {
        const panel = makePanel();
        const c = panel.controller;
        c.handleSecretEvent({event: "requested", request_id: "deadline", data: {
            secret_keys: ["psk"], timeout_ms: 300, save_supported: true
        }});
        const dialog = panel.page.children.find(item => item.visible && item.prompt === c.prompt && item.maximumCardWidth === 620);
        const field = findChild(dialog, "fieldInput");
        verify(!!field);
        field.forceActiveFocus();
        keyClick(Qt.Key_A);
        compare(c.prompt.credentialValues.psk, "a");
        tryCompare(c.prompt, "credentialOpen", false);
        compare(c.prompt.credentialValues, ({}));
        verify(c.status.includes("expired"));
        dialog.accepted({psk: "late-synthetic"});
        verify(!calls.some(call => call.method === "wifi.secret.provide" || call.method === "wifi.connectTarget"), "a queued submit after expiry cannot become a new connection");
        c.backend.handleSecretResponse({protocol: "nm-api", version: 2, ok: true, data: {result: {
            request_id: "deadline", accepted: true, status: "accepted"
        }}});
        verify(c.status.includes("expired"));
        verify(!calls.some(call => call.method === "wifi.secret.provide"));
    }
    function statusReply(c, result, id) {
        c.backend.acceptSharedResponse(id || c.connection.recoveryId, {protocol: "nm-api", version: 2, ok: true, data: {result: result}}, "");
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
        const power = findChild(panel, "chooserPowerToggle");
        verify(!power.enabled);
        const before = calls.length;
        mouseClick(power);
        compare(calls.length, before, "a QR connection blocks conflicting power writes");
    }
}
