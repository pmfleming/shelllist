pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Wifi as Wifi
import Shelllist.Ui as Ui

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
    function test_healthFeedbackUsesOnlyTheNativeRecommendationAndMessage() {
        const c = makePanel().controller;
        c.status = "Connection outcome";
        c.health.handleEvent({event:"changed", data:{health:{notification_recommended:false, state_name:"failed", reason:{name:"no-secrets"}, message:"suppressed"}}});
        compare(c.status, "Connection outcome");
        c.health.handleEvent({event:"changed", data:{health:{notification_recommended:true, state_name:"failed", reason:{name:"no-secrets"}}}});
        compare(c.status, "Connection outcome", "missing native copy never invokes a local reason table");
        const event = {event:"changed", data:{health:{notification_recommended:true, message:"Native health feedback"}}};
        c.health.handleEvent(event);
        compare(c.status, "Native health feedback");
        c.status = "Another observation";
        c.health.handleEvent(event);
        compare(c.status, "Native health feedback", "the frontend has no second wall-clock deduplicator");
        compare(calls.length, 0);
    }
    function test_diagnosticCardsFitContentInsteadOfStretchingWithPanelHeight() {
        const panel = makePanel();
        openNetwork(panel, false);
        let connectionCard = null;
        let networkCard = null;
        tryVerify(function () {
            connectionCard = findChild(panel, "wifiConnectionCard");
            networkCard = findChild(panel, "wifiNetworkDetailsCard");
            return connectionCard && networkCard && connectionCard.implicitHeight > 0;
        });
        function checkContentSizing() {
            verify(waitForPolish(panel.Window.window));
            tryVerify(() => Math.abs(connectionCard.height - connectionCard.implicitHeight) < 1);
            tryVerify(() => Math.abs(networkCard.height - networkCard.implicitHeight) < 1);
            verify(Math.abs(networkCard.y - connectionCard.y - connectionCard.height - Ui.Theme.spacingMd) < 1,
                "Network details follows Connection with only the shared card gap");
        }
        checkContentSizing();
        const connectionHeight = connectionCard.height;
        const networkHeight = networkCard.height;
        panel.height = 1200;
        checkContentSizing();
        compare(connectionCard.height, connectionHeight, "a taller panel must not add blank space below telemetry");
        compare(networkCard.height, networkHeight);
        panel.height = 560;
        checkContentSizing();
        compare(connectionCard.height, connectionHeight, "a short viewport scrolls rather than shrinking text");
        compare(connectionCard.entries.length, 8);
        compare(networkCard.entries.length, 4);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_Tab);
        tryCompare(panel.page.detailsNavigation.currentTarget, "objectName", "wifiRememberNetwork");
        compare(calls.length, 0, "resizing and browsing diagnostics never change network settings");
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
        statusReply(c, {request_id: "connect-owned", status: "running", stream: "wifi.connect", operation_revision: 2,
            event: {request_id: "connect-owned", stream: "wifi.connect", operation_revision: 2, event: "progress", data: {message: "Verifying Wi-Fi activation"}}});
        compare(c.status, "Verifying Wi-Fi activation");
        keyClick(Qt.Key_X, Qt.AltModifier);
        verify(c.connection.cancellationRequested, "active link must not hide pending cancellation");
        verify(c.actionInFlight, "cancel dispatch is not acknowledgement");
        c.connection.handleEvent({request_id: "other", event: "cancelled", data: {}});
        verify(c.actionInFlight, "foreign cancellation cannot release the guard");
        c.connection.handleEvent({request_id: "connect-owned", stream: "wifi.connect", operation_revision: 3, event: "cancelled", data: {}});
        verify(!c.actionInFlight);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(calls.slice(-1)[0].method, "wifi.disconnect");
        verify(c.actionInFlight);
    }
    function retentionNetwork(panel, active, remember) {
        const profile = remember === null ? null : {path: "/profile/cafe", id: "Cafe", remember: remember, autoconnect: true};
        panel.controller.applyNetworks([{key: "cafe", ssid: "Cafe", active: active, strength: 70,
            security: "Open", capabilities: {can_connect: true, can_toggle_autoconnect: true},
            primary_profile: profile}], true, {});
    }
    function test_rememberVisibleAndAcknowledgedForActiveAndInactiveNetworks_data() {
        return [{tag: "connected", active: true}, {tag: "disconnected", active: false}];
    }
    function test_rememberVisibleAndAcknowledgedForActiveAndInactiveNetworks(data) {
        const panel = makePanel();
        openNetwork(panel, data.active);
        retentionNetwork(panel, data.active, true);
        const c = panel.controller;
        const toggle = findChild(panel, "wifiRememberNetwork");
        tryVerify(() => toggle && toggle.visible && toggle.enabled && toggle.checked);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_Tab);
        compare(panel.page.detailsNavigation.currentTarget, toggle);
        verify(panel.page.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        const request = calls.filter(call => call.method === "wifi.profile.operation" && call.params.operation === "set-remember");
        compare(request.length, 1);
        compare(request[0].params, {operation: "set-remember", path: "/profile/cafe", enabled: false});
        verify(toggle.checked, "dispatch cannot acknowledge deletion or retention");
        verify(!toggle.enabled);
        verify(!c.status.includes("deleted"));
        mouseClick(toggle);
        compare(calls.filter(call => call.params.operation === "set-remember").length, 1);
        const message = data.active ? "Network details will be deleted when you disconnect."
            : "Saved network details deleted. Future connections won't be remembered.";
        c.backend.acceptSharedResponse("profile", {protocol: "nm-api", version: 2, ok: true,
            data: {result: {status: "ok", message: message}}}, "");
        compare(c.status, message);
        c.setBackgroundStatus("Scan complete");
        compare(c.status, message, "background reads cannot erase the toggle explanation immediately");
        retentionNetwork(panel, data.active, data.active ? false : null);
        tryCompare(toggle, "checked", false);
        verify(toggle.visible);
        const auto = c.detailActions.find(action => action.id === "autoconnect");
        verify(!auto.enabled);
        verify(!c.actions.autoconnectEnabled(c.detailAp));
        c.backend.pending = ({});
        if (data.active) {
            mouseClick(toggle);
            compare(calls.slice(-1)[0].params, {operation: "set-remember", path: "/profile/cafe", enabled: true});
            verify(!toggle.checked);
            c.backend.acceptSharedResponse("profile", {protocol: "nm-api", version: 2, ok: true,
                data: {result: {status: "ok", message: "Network details saved for future connections."}}}, "");
            retentionNetwork(panel, true, true);
            tryCompare(toggle, "checked", true);
        }
    }
    function test_rememberFailureAndLegacySnapshotsNeverPromiseDeletion() {
        const panel = makePanel();
        openNetwork(panel, true);
        retentionNetwork(panel, true, true);
        const c = panel.controller;
        const toggle = findChild(panel, "wifiRememberNetwork");
        tryVerify(() => toggle && toggle.enabled);
        mouseClick(toggle);
        c.backend.acceptSharedResponse("profile", null, "permission denied");
        verify(toggle.checked);
        verify(c.status.includes("permission denied"));
        verify(!c.status.includes("deleted"));
        verify(toggle.enabled, "failure permits explicit retry, not automatic replay");
        compare(calls.filter(call => call.params.operation === "set-remember").length, 1);
        retentionNetwork(panel, true, undefined);
        tryVerify(() => toggle.visible && !toggle.enabled);
    }
    function test_unsavedRememberIntentSurvivesBrowsingAndControlsNextConnect() {
        const panel = makePanel();
        openNetwork(panel, false);
        const c = panel.controller;
        const toggle = findChild(panel, "wifiRememberNetwork");
        tryVerify(() => toggle && toggle.enabled && !toggle.checked);
        mouseClick(toggle);
        verify(toggle.checked);
        compare(c.status, "Network details will be saved for future connections.");
        verify(!calls.some(call => call.params.operation === "set-remember"));
        c.applyNetworks([{key: "other", ssid: "Other", active: false, capabilities: {can_connect: true}}], true, {});
        verify(!c.connection.rememberNetwork);
        retentionNetwork(panel, false, null);
        tryCompare(toggle, "checked", true);
        compare(c.connection.targetRequest(c.detailAp).remember, true);
        mouseClick(toggle);
        verify(c.status.includes("won't be saved"));
        compare(c.connection.targetRequest(c.detailAp).remember, false);
        retentionNetwork(panel, false, true);
        retentionNetwork(panel, false, null);
        verify(!toggle.checked, "deleted profiles cannot inherit an old pre-connect opt-in");
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
        c.connection.handleEvent({request_id: "clicked-connect", stream: "wifi.connect", operation_revision: 2, event: terminal, data: {
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
