pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bluetooth as Bt
import Shelllist.Wifi as Wifi

DaemonTestCase {
    id: tests
    name: "CompactConfirmations"
    when: windowShown
    visible: true
    width: 700
    height: 780

    Component {
        id: bluetoothFactory
        Item {
            id: panel
            width: 560; height: 650
            property alias controller: controller
            property alias content: content
            Bt.BluetoothController { id: controller }
            Bt.BluetoothContent { id: content; anchors.fill: parent; controller: panel.controller }
        }
    }
    Component {
        id: wifiFactory
        Item {
            id: panel
            width: 560; height: 650
            property alias controller: controller
            property alias content: content
            Wifi.WifiController { id: controller; prompt: Wifi.WifiPromptController {} }
            Wifi.WifiContent { id: content; anchors.fill: parent; controller: panel.controller }
        }
    }
    function init() {
        clientReady = true;
        calls = [];
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign).*/);
    }
    function verifyCompact(dialog, actions = true) {
        verify(dialog.visible && dialog.compactPresentation);
        verify(!findChild(dialog, "modalDetail").visible);
        verify(!findChild(dialog, "promptActionSummary").visible);
        compare(dialog.Accessible.description, dialog.detail);
        verify(waitForPolish(dialog.Window.window));
        const title = findChild(dialog, "detailTitle");
        compare(title.elide, Text.ElideNone);
        verify(title.contentHeight <= title.height + 1, "full question wraps, never clips");
        if (actions) {
            const cancel = findChild(dialog, "detailAction:reject");
            const accept = findChild(dialog, "detailAction:accept");
            const left = cancel.mapToItem(dialog, 0, cancel.height / 2);
            const right = accept.mapToItem(dialog, 0, accept.height / 2);
            compare(left.y, right.y, "Cancel and Approve share a row");
            verify(left.x + cancel.width < right.x, "Cancel sits immediately before Approve");
            verify(title.mapToItem(dialog, title.width, 0).x < left.x, "question stays left of the pair");
            compare(Math.round(title.mapToItem(dialog, 0, title.height / 2).y), Math.round(right.y));
        }
    }
    function makeBluetooth() {
        const panel = createTemporaryObject(bluetoothFactory, tests);
        const c = panel.controller;
        c.applySnapshot({radio: {available: true, operational: true, powered: true, adapter_count: 1},
            adapters: [{key: "adapter", alias: "Adapter", powered: true}],
            devices: [{key: "buds", name: "Studio headphones", adapter_key: "adapter", paired: true, connected: true,
                battery: [], services: [], policy: {}, capabilities: {can_remove: true}}]});
        c.uiActive = true;
        wait(0);
        findChild(c, "bluetoothBackend").pending = ({});
        panel.content.listItem.focusList();
        calls = [];
        return panel;
    }
    function test_bluetoothPairingVariants_data() {
        // Consent, validated native input and remote-owned display are distinct.
        // BluetoothRecovery retains PIN clearing and queued request ownership.
        return ["service-authorization", "passkey", "display-passkey"]
            .map(kind => ({tag: kind, kind: kind}));
    }
    function test_bluetoothPairingVariants(data) {
        const panel = makeBluetooth();
        const c = panel.controller;
        const passive = data.kind.startsWith("display-");
        c.handlePairingEvent({event: "requested", data: {request_id: "owned", device_key: "buds", kind: data.kind,
            response_required: !passive, value: "482019", entered: 3, service: "0000110b-0000-1000-8000-00805f9b34fb"}});
        const dialog = findChild(panel, "bluetoothPairingPrompt");
        tryVerify(() => dialog.visible);
        verifyCompact(dialog, !passive);
        verify(!panel.content.navigationEnabled);
        const input = findChild(dialog, "promptInput");
        const inputRequired = data.kind === "passkey";
        compare(input.visible, inputRequired);
        compare(findChild(dialog, "bluetoothPairingCode").visible, !inputRequired);
        if (data.kind === "service-authorization")
            verify(dialog.Accessible.description.includes("0000110b-0000-1000-8000-00805f9b34fb"));
        if (passive) {
            compare(dialog.actions.length, 0);
            compare(dialog.instruction, "");
            keyClick(Qt.Key_Escape);
            keyClick(Qt.Key_Enter);
            compare(calls.filter(call => call.method === "bluetooth.pairing.respond").length, 0);
            verify(dialog.visible, "remote-owned progress has no local approval/rejection");
            compare(findChild(dialog, "bluetoothPairingProgress").text, "3 / 6 digits");
        } else {
            if (inputRequired) {
                tryVerify(() => input.inputActiveFocus);
                verify(input.password);
                compare(input.maximumLength, 6);
                verify(!dialog.acceptEnabled);
                keyClick(Qt.Key_A);
                keyClick(Qt.Key_Return);
                verify(!dialog.acceptEnabled);
                compare(calls.filter(call => call.method === "bluetooth.pairing.respond").length, 0);
                keyClick(Qt.Key_A, Qt.ControlModifier);
                for (let i = 1; i <= 6; ++i) keyClick(Qt.Key_0 + i);
                verify(dialog.acceptEnabled);
                compare(calls.filter(call => call.method === "bluetooth.pairing.respond").length, 0);
                keyClick(Qt.Key_Return);
            } else {
                tryCompare(findChild(dialog, "detailAction:reject"), "activeFocus", true);
                keyClick(Qt.Key_Tab);
                keyClick(Qt.Key_Return);
            }
            const writes = calls.filter(call => call.method === "bluetooth.pairing.respond");
            compare(writes.length, 1);
            compare(writes[0].params.request_id, "owned");
            verify(writes[0].params.accept);
            if (inputRequired) compare(writes[0].params.value, "123456");
            verify(c.pairingResponsePending);
            keyClick(Qt.Key_Enter);
            compare(calls.filter(call => call.method === "bluetooth.pairing.respond").length, 1, "no replay while awaiting acknowledgement");
        }
    }
    function test_bluetoothForgetCancelAndAccept() {
        const panel = makeBluetooth();
        const c = panel.controller;
        const action = c.provider.actionsForDevice(c.allDevices[0]).find(a => a.id === "forget");
        c.pendingConfirmationAction = action;
        const dialog = findChild(panel, "bluetoothForgetConfirmation");
        tryCompare(findChild(dialog, "detailAction:reject"), "activeFocus", true);
        verifyCompact(dialog);
        keyClick(Qt.Key_Escape);
        verify(!c.confirmationOpen);
        compare(calls.length, 0);
        c.pendingConfirmationAction = action;
        tryCompare(findChild(dialog, "detailAction:reject"), "activeFocus", true);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        verify(!c.confirmationOpen);
        const writes = calls.filter(call => call.method === "bluetooth.device.operation");
        compare(writes.length, 1);
        compare(writes[0].params.key, "buds");
    }
    function test_wifiTypedChallengeAndCredentialOptOut() {
        const panel = createTemporaryObject(wifiFactory, tests);
        const c = panel.controller;
        const ap = {key: "cafe", ssid: "Cafe", active: true, strength: 70, security: "wpa2", profiles: [{id: "Cafe"}]};
        c.applyNetworks([ap], true, {});
        c.uiActive = true;
        wait(0);
        c.backend.pending = ({});
        panel.content.listItem.focusList();
        calls = [];
        c.prompt.openForgetPrompt(ap, true, ap.profiles);
        const dialog = findChild(panel, "wifiPrompt");
        const input = findChild(dialog, "promptInput");
        tryVerify(() => input.inputActiveFocus);
        verifyCompact(dialog);
        compare(dialog.title, "Disconnect & forget Cafe?");
        compare(dialog.inputLabel, "Type FORGET");
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Return);
        compare(calls.length, 0);
        verify(c.prompt.open && !dialog.acceptEnabled);
        keyClick(Qt.Key_Escape);
        verify(!c.prompt.open);
        compare(calls.length, 0);
        c.prompt.openForgetPrompt(ap, true, ap.profiles);
        tryVerify(() => input.inputActiveFocus);
        for (const key of [Qt.Key_Space, Qt.Key_F, Qt.Key_O, Qt.Key_R, Qt.Key_G, Qt.Key_E, Qt.Key_T, Qt.Key_Space]) keyClick(key);
        verify(dialog.acceptEnabled, "existing trimmed/case-insensitive challenge remains valid");
        compare(calls.length, 0, "typing does not submit");
        keyClick(Qt.Key_Return);
        verify(!c.prompt.open);
        const write = calls.find(call => call.params.operation === "forget");
        verify(!!write);
        compare(write.params.key, "cafe");
        // Password prompts using the same component are not this confirmation.
        c.prompt.openPasswordPrompt(ap);
        tryVerify(() => input.inputActiveFocus);
        verify(!dialog.compactPresentation);
        verify(findChild(dialog, "modalDetail").visible);
        compare(dialog.inputLabel, "Password");
        keyClick(Qt.Key_Escape);
    }
}
