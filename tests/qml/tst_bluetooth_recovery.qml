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
            function release(id, route) {}
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
    Component {
        id: contentComponent
        Bt.BluetoothContent {}
    }
    Component { id: spyComponent; SignalSpy {} }
    function test_headerScreenshotAndSearchSettingsAreSeparate() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, panel, {controller: controller, width: 720, height: 1000});
        verify(content !== null);
        tryVerify(() => content.listItem !== null);
        const pane = content.listItem;
        const spy = createTemporaryObject(spyComponent, panel, {target: controller, signalName: "screenshotRequested"});
        const button = findChild(pane, "chooserIconButton");
        verify(button !== null && button.clickable);
        compare(button.Accessible.name, "Take a screenshot");
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(spy.count, 1);
        verify(!controller.detailsOpen);
        const scope = controller.searchScope;
        pane.searchActionRequested();
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "adapter");
        compare(controller.searchScope, scope);
        compare(spy.count, 1);
        verify(findChild(pane, "bluetoothOptionsPopup") === null);
        verify(content.navigationEnabled);
        pane.focusSearch();
        keyClick(Qt.Key_Escape);
        tryCompare(controller, "detailsOpen", false);
        controller.handlePairingEvent({event: "requested", data: {request_id: "pair", device_key: "buds", response_required: true}});
        verify(!pane.iconActionEnabled && !pane.searchActionEnabled);
        pane.iconClicked();
        pane.searchActionRequested();
        compare(spy.count, 1);
        verify(!controller.detailsOpen);
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
    function test_listOptionsPersistAndReflectAcknowledgedSettings() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.openBluetoothSettings();
        const page = createTemporaryObject(adapterPageComponent, panel, {controller: controller, width: 320, height: 500});
        verify(findChild(page, "bluetoothListOptions") !== null);
        for (const setting of [
            {name: "showBlockedDevices", field: "show_blocked_devices"},
            {name: "showRecentDevices", field: "show_recent_devices"}
        ]) {
            const toggle = findChild(page, setting.name);
            verify(toggle.visible && toggle.interactive);
            verify(!toggle.checked);
            toggle.clicked();
            compare(calls[calls.length - 1].method, "bluetooth.management.update");
            compare(calls[calls.length - 1].params[setting.field], true);
            verify(!toggle.interactive);
            verify(!toggle.checked); // Wait for the daemon's persisted snapshot.
            const management = Object.assign({}, controller.management, {[setting.field]: true});
            controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: controller.allDevices, management: management});
            findChild(controller, "bluetoothBackend").pending = ({});
            verify(toggle.checked && toggle.interactive);
        }
        compare(calls.length, 2);
        const scope = findChild(page, "bluetoothSearchScope");
        scope.selected("all");
        verify(controller.searchAllDevices);
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "adapter");
        compare(calls[calls.length - 1].method, "bluetooth.scan");
        findChild(controller, "bluetoothBackend").pending = ({});
        scope.selected("mine");
        verify(!controller.searchAllDevices);
        verify(controller.detailsOpen);
        const reopened = createTemporaryObject(adapterPageComponent, panel, {controller: controller, width: 320, height: 500});
        verify(findChild(reopened, "showBlockedDevices").checked);
        verify(findChild(reopened, "showRecentDevices").checked);
        compare(findChild(reopened, "bluetoothSearchScope").value, "mine");
    }
    function test_emptyListCanOpenBluetoothSettings() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: []});
        verify(!controller.hasSelection);
        controller.openDetails();
        verify(!controller.detailsOpen);
        const pane = createTemporaryObject(listPaneComponent, panel, {controller: controller, width: 320, height: 500});
        verify(pane.searchActionEnabled);
        pane.searchActionRequested();
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "adapter");
        const details = createTemporaryObject(detailsComponent, panel, {controller: controller, width: 600, height: 900});
        verify(details.contentAvailable);
        compare(details.title, "Bluetooth");
        tryVerify(() => findChild(details, "bluetoothListOptions") !== null);
        // Losing a selection must not implicitly open global settings.
        controller.detailsTab = "device";
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: [{key: "test", name: "Test", paired: true, capabilities: {}}]});
        verify(controller.hasSelection);
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: []});
        compare(controller.detailsTab, "device");
        verify(!controller.detailsOpen);
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
    Component {
        id: adapterPageComponent
        Bt.BluetoothAdapterPage {}
    }
    function test_bluetoothSettingsUseGlobalScopeAndDefaults() {
        const panel = makePanel();
        const controller = panel.controller;
        const details = createTemporaryObject(detailsComponent, panel, {controller: controller, width: 600, height: 900});
        controller.openDetails();
        const tabs = findChild(details, "bluetoothDetailsTabs");
        compare(tabs.tabs.map(tab => tab.value), ["device", "information"]);
        verify(controller.cycleDetailsTab());
        compare(controller.detailsTab, "information");
        verify(controller.cycleDetailsTab());
        compare(controller.detailsTab, "device");
        controller.openBluetoothSettings();
        compare(tabs.tabs.length, 0);
        compare(tabs.footerHeight, 0);
        verify(!controller.cycleDetailsTab());
        compare(details.title, "Bluetooth");
        compare(details.subtitle, "Computer-wide Bluetooth settings");
        compare(details.actions.length, 0);
        const page = createTemporaryObject(adapterPageComponent, panel, {controller: controller, width: 320, height: 500});
        verify(page !== null);
        wait(0);
        verify(findChild(page, "showBlockedDevices") !== null);
        for (const setting of [
            {name: "defaultTrustAfterPairing", field: "trust_after_pair"},
            {name: "defaultReconnectAfterWake", field: "reconnect_on_resume"}
        ]) {
            const toggle = findChild(page, setting.name);
            verify(toggle.checked && toggle.interactive);
            toggle.clicked();
            compare(calls[calls.length - 1].method, "bluetooth.management.update");
            compare(calls[calls.length - 1].params[setting.field], false);
            compare(calls[calls.length - 1].params.key, undefined);
            findChild(controller, "bluetoothBackend").pending = ({});
        }
        compare(calls.length, 2);
        controller.toggleDetails();
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "device");
    }
    function test_radioSelectionAndPowerAreControlledInBluetoothSettings() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applySnapshot({radio: {available: true, operational: true, powered: true, adapter_count: 2},
            adapters: [{key: "adapter", alias: "Built-in", powered: true}, {key: "usb", alias: "USB", powered: false}],
            devices: controller.allDevices});
        controller.openBluetoothSettings();
        const page = createTemporaryObject(adapterPageComponent, panel, {controller: controller, width: 320, height: 500});
        wait(0);
        const selector = findChild(page, "bluetoothRadioSelector");
        verify(selector.visible && selector.interactive);
        selector.selected("usb");
        compare(calls[calls.length - 1].method, "bluetooth.management.update");
        compare(calls[calls.length - 1].params.preferred_adapter_key, "usb");
        compare(controller.selectedAdapter.key, "usb");
        const backend = findChild(controller, "bluetoothBackend");
        backend.pending = ({});
        const power = findChild(page, "bluetoothRadioPower");
        verify(!power.checked && power.interactive);
        power.clicked();
        compare(calls[calls.length - 1].method, "bluetooth.setPowered");
        compare(calls[calls.length - 1].params.adapter_key, "usb");
        compare(calls[calls.length - 1].params.powered, true);
        backend.pending = ({});
        controller.applySnapshot({radio: {available: false, adapter_count: 0, powered: false}, adapters: [], devices: []});
        verify(!selector.visible && !power.interactive);
        verify(controller.detailsOpen);
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
    function test_pairingInputSurvivesUnrelatedOperationsAndQueueRecovery() {
        const controller = makePanel().controller;
        const first = {request_id: "pair-a", device_key: "a", kind: "passkey", response_required: true};
        const second = {request_id: "pair-b", device_key: "b", kind: "passkey", response_required: true};
        controller.handlePairingEvent({event: "requested", data: first});
        controller.pairingInput = "123456";
        controller.handleOperationEvent({request_id: "op-c", device_key: "c", operation: "connect", state: "completed"});
        compare(controller.pairingPrompt.request_id, "pair-a");
        compare(controller.pairingInput, "123456");
        controller.applyRequestSnapshot({pairing: {active: [first, second]}});
        compare(controller.pairingInput, "123456");
        controller.applyRequestSnapshot({pairing: {active: [second, first]}});
        compare(controller.pairingInput, "");
        controller.pairingInput = "654321";
        controller.applyRequestSnapshot({pairing: {active: [first, second]}});
        compare(controller.pairingInput, "123456");
        controller.closePairingForDevice("a");
        compare(controller.pairingInput, "654321");
        compare(controller.pairingInputs["pair-a"], undefined);
        controller.invalidateBluetooth("Disconnected");
        compare(controller.pairingInput, "");
        compare(Object.keys(controller.pairingInputs).length, 0);
    }
    function test_pendingPairingReplyKeepsItsOriginalRequestIdentity() {
        const controller = makePanel().controller;
        controller.handlePairingEvent({event: "requested", data: {request_id: "a", device_key: "a", response_required: true}});
        controller.pairingInput = "123456";
        verify(controller.respondPairing(true));
        controller.handlePairingEvent({event: "requested", data: {request_id: "b", device_key: "b", response_required: true}});
        controller.closePairingForDevice("a");
        controller.pairingInput = "654321";
        verify(!controller.respondPairing(true));
        compare(controller.respondingPairingId, "a");
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-response", {protocol: "bt-api", version: 1, ok: true, data: {}}, "");
        compare(controller.pairingPrompt.request_id, "b");
        compare(controller.pairingInput, "654321");
        verify(controller.respondPairing(true));
        compare(calls[calls.length - 1].params.request_id, "b");
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
    function test_renameDraftSurvivesFailureAndEditorRecreation() {
        const panel = makePanel();
        const controller = panel.controller;
        const backend = findChild(controller, "bluetoothBackend");
        verify(controller.renameSelected("My renamed buds"));
        verify(controller.nameEdits.draft("buds").dirty);
        verify(controller.nameEdits.draft("buds").pending);
        backend.acceptSharedResponse("device-set-alias", {protocol: "bt-api", version: 1, ok: true,
            data: {operation: {request_id: "rename-1", device_key: "buds", operation: "set-alias", state: "running"}}}, "");
        controller.handleOperationEvent({request_id: "rename-1", device_key: "buds", operation: "set-alias", state: "failed", error: {message: "Permission denied"}});
        wait(0);
        compare(findChild(panel.page, "deviceNameInput").text, "My renamed buds");
        const callCount = calls.length;
        wait(750);
        compare(calls.length, callCount); // Failed saves must not retry indefinitely.
        const newPage = createTemporaryObject(devicePageComponent, panel, {controller: controller, width: 600, height: 900});
        wait(0);
        compare(findChild(newPage, "deviceNameInput").text, "My renamed buds");
        findChild(newPage, "retryDeviceName").clicked();
        compare(calls[calls.length - 1].params.alias, "My renamed buds");
        backend.acceptSharedResponse("device-set-alias", {protocol: "bt-api", version: 1, ok: false, error: {message: "Adapter unavailable"}}, "");
        verify(controller.nameEdits.draft("buds").dirty);
        verify(!controller.nameEdits.draft("buds").pending);
        findChild(newPage, "discardDeviceName").clicked();
        compare(findChild(newPage, "deviceNameInput").text, "Buds");
        compare(controller.nameEdits.draft("buds"), null);
    }
    Component { id: devicePageComponent; Bt.BluetoothDevicePage {} }
    function test_adapterDraftsOnlyClearAfterAcknowledgement() {
        const panel = makePanel();
        const controller = panel.controller;
        const edits = controller.adapterEdits;
        const backend = findChild(controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "My adapter");
        edits.edit("adapter", "discoverableTimeout", 120);
        verify(edits.saveNext("adapter"));
        compare(edits.draft("adapter").fields.alias, "My adapter");
        backend.acceptSharedResponse("adapter-set-alias", {protocol: "bt-api", version: 1, ok: false, error: {message: "Permission denied"}}, "");
        const previousCalls = calls.length;
        wait(750);
        compare(calls.length, previousCalls);
        const page = createTemporaryObject(adapterPageComponent, panel, {controller: controller, width: 600, height: 900});
        wait(0);
        compare(findChild(page, "adapterNameInput").text, "My adapter");
        findChild(page, "retryAdapterSettings").clicked();
        compare(calls[calls.length - 1].params.alias, "My adapter");
        backend.acceptSharedResponse("adapter-set-alias", {protocol: "bt-api", version: 1, ok: true,
            data: {snapshot: {radio: controller.radio, devices: controller.allDevices,
                adapters: [{key: "adapter", alias: "My adapter", powered: true}]}}}, "");
        wait(0);
        compare(edits.draft("adapter").fields.alias, undefined);
        compare(calls[calls.length - 1].params.operation, "set-discoverable-timeout");
        compare(calls[calls.length - 1].params.timeout, 120);
        backend.acceptSharedResponse("adapter-set-discoverable-timeout", {protocol: "bt-api", version: 1, ok: true,
            data: {snapshot: {radio: controller.radio, devices: controller.allDevices,
                adapters: [{key: "adapter", alias: "My adapter", powered: true, discoverable_timeout: 120}]}}}, "");
        compare(Object.keys(edits.draft("adapter").fields).length, 0);
    }
    function test_renameAcknowledgementAndDisconnectKeepCorrectState() {
        const panel = makePanel();
        const controller = panel.controller;
        verify(controller.renameSelected("New name"));
        const snapshot = {radio: controller.radio, adapters: controller.adapters,
            devices: [Object.assign({}, controller.selectedDevice, {name: "New name", alias: "New name"})]};
        controller.handleOperationEvent({request_id: "rename-1", device_key: "buds", operation: "set-alias", state: "completed", snapshot: snapshot});
        compare(controller.nameEdits.draft("buds"), null);
        compare(findChild(panel.page, "deviceNameInput").text, "New name");
        findChild(controller, "bluetoothBackend").pending = ({});
        verify(controller.renameSelected("Keep on disconnect"));
        findChild(controller, "bluetoothBackend").failSharedTransport("Disconnected");
        const draft = controller.nameEdits.draft("buds");
        compare(draft.value, "Keep on disconnect");
        verify(draft.dirty && !draft.pending && draft.error.length > 0);
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
