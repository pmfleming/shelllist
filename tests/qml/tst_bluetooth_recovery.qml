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
        id: listPaneComponent
        Bt.BluetoothDeviceListPane {
            resultModel: ListModel {}
            rowDelegate: Component { Item { width: 100; height: 40 } }
        }
    }
    function test_emptyRadioIcon() {
        const panel = makePanel();
        const controller = panel.controller;
        const pane = createTemporaryObject(listPaneComponent, panel, {controller: controller, width: 500, height: 900});
        verify(pane !== null);
        const message = findChild(pane, "resultListEmptyMessage");
        verify(message !== null);
        for (const scenario of [
            {radio: {available: true, adapter_count: 1, powered: false, soft_blocked: true}, icon: true, label: "Bluetooth is blocked"},
            {radio: {available: true, adapter_count: 1, powered: false, hard_blocked: true}, icon: true, label: "Bluetooth is hardware-disabled"},
            {radio: {available: true, adapter_count: 1, powered: false}, icon: true, label: "Bluetooth is off"},
            {radio: {available: false, adapter_count: 0, powered: false}, icon: false, label: "No Bluetooth adapters"},
            {radio: {available: true, adapter_count: 1, powered: true}, icon: false, label: "No devices in My Devices"}
        ]) {
            controller.applySnapshot({radio: scenario.radio, adapters: [], devices: []});
            tryCompare(message, "visible", true);
            compare(message.text, scenario.icon ? "󰂲" : scenario.label);
            compare(message.Accessible.name, scenario.label);
        }
        pane.resultModel.append({name: "Buds"});
        tryCompare(message, "visible", false);
    }
    function test_noiseControlLayout() {
        const panel = makePanel();
        const controller = panel.controller;
        const original = controller.selectedDevice;
        let commonFontSize = 0;
        // Exercise both ring sizes without a width × topology × mode cross-product.
        for (const scenario of [
            {width: 320, components: ["left", "right"]},
            {width: 720, components: ["main"]}
        ]) {
            panel.width = scenario.width;
            const components = scenario.components;
            for (const mode of ["noise-cancelling", "off", "adaptive", "transparent"]) {
                const device = Object.assign({}, original, {
                    battery_live: true,
                    battery: components.map(function (component) { return {component: component, percentage: 100}; }),
                    fast_pair: {noise_control: {available_modes: [mode], active_mode: mode}}
                });
                controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: [device]});
                wait(0);
                const icon = findChild(panel.page, "noiseControlIcon");
                const label = findChild(panel.page, "noiseControlLabel");
                const percentage = findChild(panel.page, "batteryPercentage-" + components[0]);
                verify(icon !== null && label !== null && percentage !== null);
                tryCompare(icon, "status", Image.Ready);
                const iconBottom = icon.mapToItem(panel.page, icon.width, icon.height);
                const percentageBottom = percentage.mapToItem(panel.page, 0, percentage.height);
                fuzzyCompare(iconBottom.x, panel.page.width, 0.01);
                fuzzyCompare(iconBottom.y, percentageBottom.y, 0.01);
                fuzzyCompare(label.mapToItem(icon, label.width / 2, 0).x, icon.width / 2, 0.01);
                verify(label.mapToItem(icon, 0, 0).y > icon.height);
                verify(label.contentWidth <= icon.width * 1.5);
                compare(label.text, mode === "noise-cancelling" ? "Noise\ncancellation" : mode === "transparent" ? "Ambient" : mode === "off" ? "Off" : "Adaptive");
                if (commonFontSize)
                    compare(label.font.pixelSize, commonFontSize);
                commonFontSize = label.font.pixelSize;
            }
        }
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters,
            devices: [Object.assign({}, original, {fast_pair: null})]});
        wait(0);
        verify(!findChild(panel.page, "noiseControlIcon").visible);
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
    function findToggle(item, title) {
        if (item.title === title && item.checked !== undefined)
            return item;
        for (const child of item.children || []) {
            const match = findToggle(child, title);
            if (match)
                return match;
        }
        return null;
    }
    function test_busyPolicyDoesNotClaimUnsupported() {
        const panel = makePanel();
        findChild(panel.page, "deviceOverrides").expanded = true;
        verify(findToggle(panel.page, "Reconnect after wake").interactive);
        verify(panel.controller.updateDevicePolicy({reconnect_on_resume: false}));
        wait(0); // The action model recreates its delegates when the busy state changes.
        const row = findToggle(panel.page, "Reconnect after wake");
        verify(row !== null);
        verify(!row.interactive);
        compare(row.subtitle, "");
        findChild(panel.controller, "bluetoothBackend").pending = ({});
        wait(0);
        verify(findToggle(panel.page, "Reconnect after wake").interactive);
    }
    function test_audioPreferencesRemainEditableWithoutLiveAudio() {
        const panel = makePanel();
        const controller = panel.controller;
        const device = Object.assign({}, controller.selectedDevice, {device_type: "Headphones",
            policy: {audio_route_on_connect: "switch", preferred_audio_profile_key: "saved-profile"}});
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: [device]});
        controller.invalidateAudio("Audio service unavailable");
        wait(0);
        verify(findChild(panel.page, "deviceAudio").visible);
        verify(!findChild(panel.page, "currentAudioProfile").visible);
        const profile = findChild(panel.page, "audioProfileOnConnect");
        compare(profile.value, "saved-profile");
        compare(profile.placeholder, "Saved profile (currently unavailable)");
        verify(profile.interactive);
        profile.selected("");
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.device.policy.update");
        compare(calls[0].params.key, "buds");
        compare(calls[0].params.preferred_audio_profile_key, null);
        findChild(controller, "bluetoothBackend").pending = ({});
        const output = findChild(panel.page, "audioOutputOnConnect");
        verify(output.checked);
        output.clicked();
        compare(calls.length, 2);
        compare(calls[1].params.audio_route_on_connect, "keep");
    }
    function test_policyResetIsScopedToDeviceOverrides() {
        const panel = makePanel();
        const controller = panel.controller;
        const overrides = findChild(panel.page, "deviceOverrides");
        verify(!overrides.expanded);
        const expand = findChild(overrides, "disclosureButton");
        expand.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(overrides.expanded);
        const reset = findChild(panel.page, "resetDeviceOverrides");
        verify(reset !== null);
        compare(reset.label, "Reset device overrides");
        compare(controller.detailActions.find(action => action.id === "reset-policy").presentation.group, "overflow");
        compare(findChild(panel.page, "restoreDeviceName").label, "Restore original name");
        reset.clicked();
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.device.policy.update");
        compare(calls[0].params.key, "buds");
        for (const field of ["reconnect_on_resume", "trust_after_pair", "power_on_connect",
            "wait_for_services", "fast_pair_controls_enabled", "audio_route_on_connect", "preferred_audio_profile_key"])
            compare(calls[0].params[field], null);
        verify(!controller.triggerDetailAction("reset-policy"));
        compare(calls.length, 1);
    }
}
