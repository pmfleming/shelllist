pragma ComponentBehavior: Bound
import QtQuick
import "../../bluetooth" as Bt

DaemonTestCase {
    id: testCase
    name: "BluetoothNoiseControl"
    when: windowShown
    visible: true
    width: 1100
    height: 850

    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias surface: surface
            Bt.BluetoothController { id: controller }
            Bt.BluetoothContent {
                id: surface
                anchors.fill: parent
                controller: panel.controller
            }
        }
    }
    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign).*/);
    }
    function snapshot(mode, settable, connected, key) {
        return {
            radio: {available: true, operational: true, powered: true, adapter_count: 1},
            adapters: [{key: "adapter", alias: "Adapter", powered: true}],
            devices: [{
                key: key || "buds", name: "Buds", device_type: "earbuds", paired: true, connected: connected !== false,
                adapter_key: "adapter", services: [], policy: {audio_route_on_connect: "keep"},
                battery: [{component: "left", percentage: 100}, {component: "right", percentage: 100}],
                fast_pair: {
                    controls_available: true, account_key_available: false, authenticated_controls: false,
                    multipoint: {supported: true, enabled: true},
                    noise_control: {version: 1, active_mode: mode || "transparent",
                        available_modes: ["transparent", "adaptive", "noise-cancelling", "off"],
                        settable_modes: settable || ["transparent", "adaptive", "noise-cancelling", "off"]}
                },
                capabilities: {can_connect: true, can_disconnect: true, can_remove: true,
                    can_pair: false, can_trust: true, can_wake: false, can_block: true,
                    can_set_multipoint: false, can_set_noise_control: connected !== false}
            }]
        };
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applySnapshot(snapshot());
        wait(0);
        findChild(panel.controller, "bluetoothBackend").pending = ({});
        panel.controller.applyAudioSnapshot([{
            device_key: "buds", active_profile_key: "a2dp",
            sink: {key: "output", ready: true, is_default: true},
            source: {key: "input", ready: true, is_default: true},
            profiles: [{key: "a2dp", label: "High Fidelity Playback", codec: "sbc", available: true}]
        }]);
        panel.controller.uiActive = true;
        panel.controller.detailsOpen = true;
        tryVerify(() => findChild(panel, "bluetoothBatteryRow") !== null);
        tryVerify(() => findChild(panel, "detailAction:noise-control") !== null);
        tryVerify(() => findChild(panel, "detailAction:noise-control").surfaceShortcut === "Alt+C");
        panel.surface.listItem.focusList();
        verify(waitForRendering(panel), "settle the asynchronous detail page and Audio delegates");
        calls = [];
        return panel;
    }
    function requests() {
        return calls.filter(call => call.method === "bluetooth.device.operation");
    }
    function openKeyboard(panel) {
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryCompare(panel.controller, "noiseControlOpen", true);
        tryVerify(() => findChild(panel, "noiseControlTray") !== null);
        const tray = findChild(panel, "noiseControlTray");
        tryCompare(tray, "visible", true);
        tryVerify(() => findChild(panel, "noiseControlChoices").activeFocus);
        return tray;
    }
    function test_mouseAndKeyboardShareOverlayAndConfirmedState() {
        const panel = makePanel();
        const controller = panel.controller;
        const row = findChild(panel, "bluetoothBatteryRow");
        const page = findChild(panel, "bluetoothDevicePage");
        const audio = findChild(panel, "deviceAudio");
        verify(audio.visible && audio.height > 0, "geometry assertion must include the real Audio card");
        const before = {height: row.height, y: audio.y, contentHeight: page.contentHeight};
        const precedingFocus = panel.Window.window.activeFocusItem;
        const tray = openKeyboard(panel);
        compare(tray.width, row.width);
        compare(tray.height, row.height);
        compare(tray.x, 0);
        compare(tray.y, 0);
        compare(audio.y, before.y, "tray must not push Audio down");
        compare(row.height, before.height);
        compare(page.contentHeight, before.contentHeight);
        compare(tray.currentIndex, 0);
        keyClick(Qt.Key_Right);
        compare(tray.currentIndex, 1);
        keyClick(Qt.Key_Tab);
        compare(tray.currentIndex, 2, "Tab browses menu choices, never submits");
        keyClick(Qt.Key_D, Qt.AltModifier);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        keyClick(Qt.Key_F5);
        compare(controller.detailsTab, "device");
        compare(calls.length, 0, "underlying shortcuts are blocked while choosing");
        keyClick(Qt.Key_Escape);
        tryCompare(tray, "visible", false);
        compare(requests().length, 0);
        tryVerify(() => precedingFocus.activeFocus);

        const icon = findChild(panel, "noiseControlIcon");
        mouseClick(icon, icon.width / 2, icon.height / 2);
        tryCompare(tray, "visible", true);
        const choices = findChild(panel, "noiseControlChoices");
        tryVerify(() => choices.itemAtIndex(1) !== null);
        const adaptive = choices.itemAtIndex(1);
        mouseClick(adaptive, adaptive.width / 2, adaptive.height / 2);
        tryCompare(tray, "visible", false);
        compare(requests().length, 1);
        compare(requests()[0].params, {key: "buds", operation: "set-noise-control", mode: "adaptive"});
        compare(findChild(panel, "noiseControlLabel").text, "Ambient", "submission is not acknowledgement");
        verify(!controller.openNoiseControl(), "pending request must prevent duplicates");
        const backend = findChild(controller, "bluetoothBackend");
        backend.acceptSharedResponse("device-set-noise-control", {
            protocol: "bt-api", version: 2, ok: true,
            data: {operation: {request_id: "anc", device_key: "buds", state: "running", operation: "set-noise-control"}}
        }, "");
        verify(!controller.openNoiseControl(), "accepted operation is still pending");
        backend.handleOperationEvent({data: {request_id: "anc", device_key: "buds", state: "completed",
            operation: "set-noise-control", snapshot: snapshot("adaptive")}});
        tryCompare(findChild(panel, "noiseControlLabel"), "text", "Adaptive");
        openKeyboard(panel);
        compare(tray.currentIndex, 1, "open at device-confirmed mode");
        keyClick(Qt.Key_Return);
        compare(requests().length, 1, "selecting the active mode is a no-op");
        compare(audio.y, before.y);
        compare(page.contentHeight, before.contentHeight);
        panel.width = 820;
        verify(waitForRendering(panel));
        const narrowAudioY = audio.y;
        openKeyboard(panel);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        compare(tray.currentIndex, 3);
        const last = choices.itemAtIndex(3);
        verify(last.x + last.width <= choices.contentX + choices.width + 1,
            "narrow tray scrolls to the keyboard candidate rather than growing vertically");
        compare(audio.y, narrowAudioY);
        keyClick(Qt.Key_Escape);
    }
    function test_capabilityContextAndFailureGuards() {
        const panel = makePanel();
        const controller = panel.controller;
        const tray = findChild(panel, "noiseControlTray");
        controller.applySnapshot(snapshot("transparent", ["transparent", "off"]));
        openKeyboard(panel);
        const choices = findChild(panel, "noiseControlChoices");
        tryVerify(() => choices.itemAtIndex(1) !== null);
        const disabled = choices.itemAtIndex(1);
        verify(!disabled.enabled);
        mouseClick(disabled, disabled.width / 2, disabled.height / 2);
        compare(requests().length, 0);
        keyClick(Qt.Key_Right);
        compare(tray.currentIndex, 3, "skip modes that are not settable");
        keyClick(Qt.Key_Return);
        compare(requests().length, 1);
        compare(requests()[0].params.mode, "off");
        findChild(controller, "bluetoothBackend").acceptSharedResponse("device-set-noise-control", {
            protocol: "bt-api", version: 2, ok: false,
            error: {code: "provider-rejected", message: "Provider rejected noise control"}
        }, "");
        compare(findChild(panel, "noiseControlLabel").text, "Ambient");
        verify(controller.status.includes("Provider rejected"));
        openKeyboard(panel);
        // A new report invalidates the candidate but must not write anything.
        controller.applySnapshot(snapshot("transparent", []));
        tryCompare(tray, "visible", false);
        verify(!controller.setNoiseControl("buds", "off"));
        compare(requests().length, 1);
        controller.applySnapshot(snapshot());
        openKeyboard(panel);
        controller.applySnapshot(snapshot("transparent", undefined, true, "other-buds"));
        tryCompare(tray, "visible", false);
        verify(!controller.setNoiseControl("buds", "off"), "captured target cannot be retargeted");
        controller.applySnapshot(snapshot());
        openKeyboard(panel);
        controller.applySnapshot(snapshot("transparent", undefined, false));
        tryCompare(tray, "visible", false);
        verify(!controller.openNoiseControl());
        tryVerify(() => !findChild(panel, "detailAction:noise-control") || !findChild(panel, "detailAction:noise-control").visible);
        tryVerify(() => findChild(panel, "detailAction:connect").surfaceShortcut === "Alt+C");
        controller.applySnapshot(snapshot());
        openKeyboard(panel);
        controller.detailsTab = "settings";
        tryCompare(controller, "noiseControlOpen", false);
        // The header command also enters Device from another tab after its
        // asynchronous page loader becomes ready.
        panel.surface.listItem.focusList();
        openKeyboard(panel);
        compare(controller.detailsTab, "device");
        mouseClick(findChild(panel, "deviceAudio"), 10, 10);
        tryCompare(controller, "noiseControlOpen", false, 1000);
        compare(requests().length, 1, "outside click dismisses without submitting");
        openKeyboard(panel);
        const close = findChild(panel, "closeNoiseControlTray");
        mouseClick(close, close.width / 2, close.height / 2);
        tryCompare(controller, "noiseControlOpen", false);
        openKeyboard(panel);
        controller.deactivateUi();
        tryCompare(controller, "noiseControlOpen", false);
        verify(!controller.navigationBlocked, "closing restores the host navigation guard");
    }
}
