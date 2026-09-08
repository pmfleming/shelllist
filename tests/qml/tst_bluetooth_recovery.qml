pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io
import "../../bluetooth" as Bt

TestCase {
    id: testCase
    name: "BluetoothRecovery"
    when: windowShown
    visible: true
    width: 720
    height: 1000
    property var calls: []
    property var originalFactory
    property var originalSessions

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id, method, params) { testCase.calls = testCase.calls.concat([{id: id, method: method, params: params}]); }
            function subscribeExtra(id, streams) {}
            function cancel(id, requestId) {}
        }
    }
    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }
    function cleanupTestCase() {
        for (const name of Object.keys(Io.DaemonSessions.sessions)) Io.DaemonSessions.sessions[name].client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }
    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias page: page
            Bt.BluetoothController { id: controller }
            Bt.BluetoothDevicePage { id: page; anchors.fill: parent; controller: panel.controller }
        }
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applySnapshot({radio: { available: true, operational: true, powered: true, adapter_count: 1 },
            adapters: [{key: "adapter", alias: "Adapter", powered: true}],
            devices: [{key: "buds", name: "Buds", paired: true, connected: true, adapter_key: "adapter", battery: [], services: [],
                policy: {reconnect_on_resume: true, trust_after_pair: false, power_on_connect: true, wait_for_services: true, audio_route_on_connect: "keep"},
                fast_pair: { model_id: "aabbcc", provisioning_available: true, noise_control: {available_modes: ["off", "transparent"], settable_modes: ["off"], active_mode: "transparent"}},
                capabilities: {can_set_noise_control: true, can_provision_fast_pair: true, can_rename: true}}]});
        wait(0); // complete queued startup reconciliation before testing an action
        const backend = findChild(panel.controller, "bluetoothBackend");
        verify(backend !== null);
        backend.pending = ({});
        panel.controller.applyAudioSnapshot([{device_key: "buds", sink: {key: "output", ready: true, is_default: false},
            source: {key: "input", ready: true, is_default: false}, profiles: []}]);
        calls = [];
        verify(panel.controller.hasSelection);
        return panel;
    }
    Component {
        id: detailsComponent
        Bt.BluetoothDeviceDetails { uiScale: 1 }
    }
    function test_openDetailsFollowPowerCycleEvents() {
        const panel = makePanel();
        const controller = panel.controller;
        const details = createTemporaryObject(detailsComponent, panel, {controller: controller, width: 600, height: 900});
        verify(details !== null);
        controller.detailsOpen = true;
        compare(details.subtitle, "Connected");
        const original = controller.selectedDevice;
        const backend = findChild(controller, "bluetoothBackend");
        for (const connected of [false, true, false, true]) {
            const device = Object.assign({}, original, {connected: connected, battery_live: connected,
                battery: connected ? [{component: "left", percentage: 75}] : [],
                fast_pair: connected ? original.fast_pair : null});
            backend.handleEvent({stream: "bluetooth.changed", event: "changed", data: {snapshot: {
                radio: controller.radio, adapters: controller.adapters, devices: [device]
            }}});
            compare(controller.selectedDevice.connected, connected);
            compare(details.subtitle, connected ? "Connected" : "Paired");
            compare(controller.selectedDevice.battery_live, connected);
            verify(controller.detailsOpen);
            wait(0);
        }
    }
    function test_unavailableInvalidatesCapabilitiesAndSelection() {
        const panel = makePanel(); const controller = panel.controller;
        controller.handlePairingEvent({event: "requested", data: {request_id: "a", device_key: "buds", response_required: true}});
        controller.invalidateBluetooth("BlueZ unavailable");
        verify(!controller.hasSelection);
        verify(controller.globalRequestInFlight);
        compare(controller.audioDevices.length, 0);
        compare(controller.adapters.length, 0);
        compare(controller.pairingPrompts.length, 0);
        verify(!controller.setAudioDefault({key: "stale", ready: true}));
        compare(calls.length, 0);
    }
    function test_audioUnavailableDoesNotLeaveStaleRoutes() {
        const panel = makePanel();
        panel.controller.invalidateAudio("PipeWire unavailable");
        compare(panel.controller.audioDevices.length, 0);
        verify(panel.controller.backendAvailable);
        verify(panel.controller.hasSelection);
    }
    function test_concurrentPairingDoesNotLoseTheFirstPromptOrInput() {
        const controller = makePanel().controller;
        controller.handlePairingEvent({event: "requested", data: {request_id: "a", device_key: "a", response_required: true}});
        controller.pairingInput = "123456";
        controller.handlePairingEvent({event: "requested", data: {request_id: "b", device_key: "b", response_required: true}});
        compare(controller.pairingPrompt.request_id, "a");
        compare(controller.pairingInput, "123456");
        controller.handlePairingEvent({event: "cancelled", data: {request_id: "b"}});
        compare(controller.pairingPrompt.request_id, "a");
        compare(controller.pairingPrompts.length, 1);
    }
    function test_failedPairingResponseKeepsPromptAndInput() {
        const panel = makePanel(); const controller = panel.controller;
        controller.handlePairingEvent({event: "requested", data: {request_id: "a", device_key: "buds", kind: "passkey", response_required: true}});
        controller.pairingInput = "123456";
        verify(controller.respondPairing(true));
        verify(controller.pairingResponsePending);
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-response",
            {protocol: "bt-api", version: 1, ok: false, error: {code: "pairing-response-rejected", message: "Try again"}}, "");
        verify(!controller.pairingResponsePending);
        compare(controller.pairingPrompt.request_id, "a");
        compare(controller.pairingInput, "123456");
        verify(controller.respondPairing(true));
    }
    function test_defaultRouteUsesOpaqueKeys() {
        const controller = makePanel().controller;
        verify(controller.setAudioDefault(controller.selectedSink));
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.audio.setDefault");
        compare(calls[0].params.device_key, "buds");
        compare(calls[0].params.endpoint_key, "output");
    }
    function test_policyResetSendsNullInsteadOfOverwritingGlobalDefaults() {
        const controller = makePanel().controller;
        verify(controller.updateDevicePolicy({reconnect_on_resume: null}));
        compare(calls[0].method, "bluetooth.device.policy.update");
        compare(calls[0].params.key, "buds");
        compare(calls[0].params.reconnect_on_resume, null);
    }
    function test_policyResetToolbarAction() {
        const controller = makePanel().controller;
        const toolbar = controller.detailActions.filter(function (action) {
            return action.presentation.group === "toolbar";
        });
        compare(toolbar.map(function (action) { return action.id; }), ["reset-policy", "forget"]);
        compare(toolbar[0].label, "Reset");
        verify(toolbar[0].icon.length > 0);
        compare(toolbar[0].presentation, toolbar[1].presentation);
        verify(controller.triggerDetailAction("reset-policy"));
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.device.policy.update");
        compare(calls[0].params.key, "buds");
        for (const field of ["reconnect_on_resume", "trust_after_pair", "power_on_connect",
            "wait_for_services", "audio_route_on_connect", "preferred_audio_profile_key"])
            compare(calls[0].params[field], null);
        verify(!controller.triggerDetailAction("reset-policy"));
        compare(calls.length, 1);
    }
    function test_noiseControlRejectsUnavailableModes() {
        const controller = makePanel().controller;
        verify(!controller.setNoiseControl("transparent"));
        compare(calls.length, 0);
        verify(controller.setNoiseControl("off"));
        compare(calls[0].params.operation, "set-noise-control");
        compare(calls[0].params.mode, "off");
    }
    Component {
        id: fastPairToggleComponent
        Bt.BluetoothFastPairSetup {}
    }
    function test_fastPairToggleUsesBackendState() {
        const panel = makePanel();
        const controller = panel.controller;
        const toggle = createTemporaryObject(fastPairToggleComponent, panel, {controller: controller});
        verify(toggle !== null);
        compare(toggle.title, "Fast Pair controls");
        compare(toggle.subtitle, "");
        verify(!toggle.showSubtitle);
        verify(!toggle.checked);
        verify(toggle.interactive);
        toggle.clicked();
        compare(calls.length, 1);
        compare(calls[0].params.operation, "provision-fast-pair");
        verify(!toggle.checked); // Wait for the daemon's confirmed credential state.
        verify(!toggle.interactive);
        toggle.clicked();
        compare(calls.length, 1);

        findChild(controller, "bluetoothBackend").pending = ({});
        const device = Object.assign({}, controller.selectedDevice, {
            fast_pair: Object.assign({}, controller.selectedDevice.fast_pair, {
                account_key_available: true, authenticated_controls: false
            })
        });
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: [device]});
        verify(toggle.checked); // Remains enabled even while authentication is unavailable.
        verify(!toggle.interactive); // No destructive credential removal masquerading as an off switch.
        toggle.clicked();
        compare(calls.length, 1);
    }
    function test_fastPairToggleRespectsProvisioningAvailability() {
        const panel = makePanel();
        const controller = panel.controller;
        const toggle = createTemporaryObject(fastPairToggleComponent, panel, {controller: controller});
        const device = Object.assign({}, controller.selectedDevice, {
            capabilities: Object.assign({}, controller.selectedDevice.capabilities, {can_provision_fast_pair: false})
        });
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: [device]});
        verify(!toggle.checked);
        verify(!toggle.interactive);
        toggle.clicked();
        compare(calls.length, 0);
    }
    function test_provisioningUsesDaemonTrustedMetadataNotFrontendKeys() {
        const controller = makePanel().controller;
        verify(controller.provisionFastPair());
        compare(calls[0].params.operation, "provision-fast-pair");
        compare(calls[0].params.anti_spoofing_public_key, undefined);
    }
}
