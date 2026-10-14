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
    function test_hiddenKeyboardCommandConsumesNativeFieldsAndRecoveryHint() {
        const panel = makePanel();
        openNetwork(panel, false);
        const c = panel.controller;
        keyClick(Qt.Key_F6);
        verify(!c.prompt.credentialOpen, "do not invent unsupported hidden-network options");
        c.activeStatus = {enabled: true, hidden_prompt: {
            fields: [{key: "ssid", required: true, password: false, value: "Native default"}],
            security_modes: [{id: "open", security: "--", key_mgmt: "open", required_fields: [], enterprise: false}]
        }};
        keyClick(Qt.Key_F6);
        verify(c.prompt.credentialOpen);
        compare(c.prompt.credentialValues.ssid, "Native default");
        compare(c.prompt.credentialFields.length, 1);
        const dialog = panel.page.children.find(item => item.visible && item.prompt === c.prompt && item.maximumCardWidth === 620);
        verify(!!dialog);
        dialog.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(!c.prompt.credentialOpen);
        c.connection.lastConnectAp = {key: "cafe", ssid: "Cafe"};
        c.connection.handleConnectError({reason: "wrong-password"});
        verify(!c.prompt.open, "raw reason strings cannot synthesize recovery policy");
        c.connection.handleConnectError({recovery_prompt: {kind: "password", message: "Native recovery"}});
        verify(!c.prompt.open, "terminal failures never start a second credential transaction");
        c.prompt.cancel();
        verify(!calls.some(call => call.method === "wifi.connectTarget"), "opening/discarding prompts never connects");
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
        return [{tag: "failure", ok: false}];
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
        c.backend.acceptSharedResponse("disconnect", {protocol: "nm-api", version: 2, ok: data.ok, data: {result: {message: "Disconnected Wi-Fi"}}, error: {code: "failed", message: "Disconnect failed"}}, "");
        verify(!c.actionInFlight);
        verify(findChild(panel, "chooserPowerToggle").enabled);
        if (!data.ok) {
            verify(c.status.indexOf("Disconnect failed") >= 0);
            panel.page.listItem.focusList();
            keyClick(Qt.Key_D, Qt.AltModifier);
            verify(c.backend.isPending("disconnect"), "explicit retry remains available");
        }
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
        return ["secret-required", "succeeded"].map(outcome => ({tag: outcome, outcome: outcome}));
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
    function test_updateCredentialsIsExplicitVersionedEditorNotAnotherConnect_data() {
        return [{tag: "leaving-hardware", hardware: true}];
    }
    function test_updateCredentialsIsExplicitVersionedEditorNotAnotherConnect(data) {
        const panel = makePanel();
        savedNetwork(panel);
        const c = panel.controller;
        if (data.hardware)
            c.advanced.openSettings("hardware");
        const leaving = [];
        c.advancedSectionLeaving.connect(section => leaving.push(section));
        const button = panel.page.detailsNavigation.commandButtons.find(button => button.accessKey === "U");
        verify(!!button && button.enabled);
        mouseClick(button);
        verify(c.advanced.open);
        compare(c.advanced.section, "security");
        compare(c.advanced.profilePath, "/profile/cafe");
        compare(leaving, data.hardware ? ["hardware"] : [], "existing field-leaving rules are preserved");
        verify(!calls.some(call => call.method === "wifi.connectTarget"));
        verify(!c.prompt.open && !c.prompt.credentialOpen);
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
    function test_secretEnterWaitsForAcknowledgementAndExpires() {
        const panel = makePanel();
        const c = panel.controller;
        c.connection.requestId = "connect-in-progress";
        c.handleSecretEvent({event: "requested", request_id: "secret-owned", data: {
            secret_keys: ["psk"], save_supported: true
        }});
        // Select the credential form's input rather than the panel search.
        const dialog = panel.page.children.find(item => item.visible && item.prompt === c.prompt && item.maximumCardWidth === 620);
        verify(!!dialog);
        const password = findChild(dialog, "fieldInput");
        verify(!!password);
        password.forceActiveFocus();
        keyClick(Qt.Key_A);
        compare(c.prompt.credentialValues.psk, "a");
        keyClick(Qt.Key_Return);
        compare(calls.slice(-1)[0].method, "wifi.secret.provide");
        compare(calls.slice(-1)[0].params.values.psk, "a");
        verify(c.prompt.credentialOpen, "dispatch does not discard the password");
        verify(c.prompt.secretSubmitting);
        c.backend.handleSecretResponse({protocol: "nm-api", version: 2, ok: true, data: {result: {request_id: "foreign", accepted: true, status: "accepted"}}});
        verify(c.prompt.credentialOpen);
        c.backend.handleSecretResponse({protocol: "nm-api", version: 2, ok: true, data: {result: {request_id: "secret-owned", accepted: false, status: "unavailable"}}});
        verify(!c.prompt.credentialOpen);
        verify(c.status.includes("expired"));
        c.handleSecretEvent({event: "requested", request_id: "secret-next", data: {secret_keys: ["psk"]}});
        c.handleSecretEvent({event: "cancelled", request_id: "secret-owned", data: {reason: "expired"}});
        verify(c.prompt.credentialOpen, "old expiry cannot close a newer request");
        c.handleSecretEvent({event: "cancelled", request_id: "secret-next", data: {reason: "expired"}});
        verify(!c.prompt.credentialOpen);
    }

    function test_receiptDeliveryAndSaveFailureRemainDistinct_data() {
        return ["rdp", "dpr", "prd"].map(order => ({tag: order, order: order}));
    }
    function test_receiptDeliveryAndSaveFailureRemainDistinct(data) {
        const panel = makePanel();
        const c = panel.controller;
        c.handleSecretEvent({event: "requested", request_id: "secret-order", data: {secret_keys: ["psk"], save_supported: true}});
        const dialog = panel.page.children.find(item => item.visible && item.prompt === c.prompt && item.maximumCardWidth === 620);
        const password = findChild(dialog, "fieldInput");
        verify(!!password);
        password.forceActiveFocus();
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Return);
        verify(c.prompt.secretSubmitting);
        let delivered = false;
        let failed = false;
        for (const step of data.order) {
            if (step === "r") {
                c.backend.handleSecretResponse({protocol: "nm-api", version: 2, ok: true, data: {result: {request_id: "secret-order", accepted: true, status: "accepted"}}});
                verify(!c.prompt.credentialOpen);
                compare(c.prompt.credentialValues, ({}));
            } else if (step === "d") {
                c.handleSecretEvent({event: "delivered", request_id: "secret-order", data: {}});
                delivered = true;
            } else {
                c.handleSecretEvent({event: "persistence", request_id: "secret-order", data: {status: "failed", error: "Keyring locked"}});
                failed = true;
            }
            verify(c.status.includes(failed ? "could not be saved" : delivered ? "sent to NetworkManager" : "received"));
        }
        c.handleSecretEvent({event: "requested", request_id: "newer-secret", data: {secret_keys: ["psk"], save_supported: true}});
        const status = c.status;
        c.handleSecretEvent({event: "delivered", request_id: "secret-order", data: {}});
        compare(c.status, status, "old delivery cannot overwrite a newer request");
    }
    function test_rememberSwitchRoutesTemporaryConnect_data() {
        return [{tag: "saved", saved: true}];
    }
    function test_rememberSwitchRoutesTemporaryConnect(data) {
        const panel = makePanel();
        if (data.saved) savedNetwork(panel);
        else openNetwork(panel, false);
        const c = panel.controller;
        const toggle = findChild(panel, "wifiRememberNetwork");
        verify(!!toggle && toggle.visible);
        verify(toggle.checked);
        mouseClick(toggle.focusSurface);
        verify(!c.connection.rememberNetwork);
        panel.page.listItem.focusList();
        keyClick(Qt.Key_C, Qt.AltModifier);
        const request = calls.find(call => call.method === "wifi.connectTarget");
        verify(!!request);
        compare(request.params.remember, false);
        compare(request.params.key, "cafe");
        compare(c.connection.targetRequest({key: "another-network"}).remember, true, "opt-out never leaks to another network");
    }

    function statusReply(c, result, id) {
        c.backend.acceptSharedResponse(id || c.connection.recoveryId, {protocol: "nm-api", version: 2, ok: true, data: {result: result}}, "");
    }
    function test_missedCompletionIsRecoveredWithoutReplayingMutation() {
        const c = makePanel().controller;
        c.connection.requestId = "connect-owned";
        c.handleDaemonEventGap("wifi.connect");
        const read = calls.filter(function (call) { return call.method === "operation.status"; });
        compare(read.length, 1);
        compare(read[0].params.request_id, "connect-owned");
        statusReply(c, {request_id: "connect-owned", status: "finished", stream: "wifi.connect", event: {request_id: "connect-owned", event: "succeeded", data: {result: {status: "connected", message: "Link connected; internet unknown"}}}});
        compare(c.connection.requestId, "");
        verify(!c.actionInFlight);
        compare(c.status, "Link connected; internet unknown");
        compare(calls.filter(function (call) { return call.method === "wifi.connectTarget"; }).length, 0);
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
        c.connection.handleEvent({request_id: "connect-owned", event: "cancelled", data: {}});
        verify(!poll.running && !deadline.running);
    }
    function test_malformedOrUnknownRecoveryNeverClaimsCompletion_data() {
        return [
            {tag: "missing", result: null},
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
