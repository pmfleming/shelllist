pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "../../bluetooth" as Bt

DaemonTestCase {
    id: testCase
    name: "BluetoothSignal"
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
            Bt.BluetoothController { id: controller }
            Bt.BluetoothContent {
                anchors.fill: parent
                controller: panel.controller
            }
        }
    }
    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign).*/);
    }
    function snapshot(signal) {
        return {
            radio: {available: true, operational: true, powered: true, adapter_count: 1},
            adapters: [{key: "adapter", alias: "Adapter", powered: true}],
            devices: [Object.assign({
                key: "headphones", name: "Headphones", paired: true, connected: true,
                adapter_key: "adapter", services: [], battery: [], policy: {}
            }, signal)]
        };
    }
    function showRow(panel, signal) {
        panel.controller.applySnapshot(snapshot(signal));
        panel.controller.uiActive = true;
        tryVerify(() => findChild(panel, "bluetoothSignalIcon") !== null);
        return {
            value: findChild(panel, "bluetoothSignalValue"),
            icon: findChild(panel, "bluetoothSignalIcon")
        };
    }

    function test_relative_classic_rssi_draws_quality_bars() {
        const panel = createTemporaryObject(panelComponent, testCase);
        const row = showRow(panel, {rssi: 0, rssi_kind: "bredr-relative", signal_strength: null,
            signal_level: 3, signal_live: true});
        // Zero is inside the golden receive range: good, never "0%" or missing.
        tryCompare(row.value, "text", "Good");
        compare(row.icon.level, 3);
        compare(row.icon.opacity, 1);
        compare(row.icon.iconColor, Ui.Theme.active);

        const cached = showRow(panel, {rssi: -14, rssi_kind: "bredr-relative", signal_strength: null,
            signal_level: 1, signal_live: false});
        tryCompare(cached.value, "text", "Weak");
        compare(cached.icon.level, 1);
        compare(cached.icon.iconColor, Ui.Theme.danger);
        verify(cached.icon.opacity > 0 && cached.icon.opacity < 1, "cached readings stay dimmed");
    }

    function test_dbm_rssi_keeps_percentage_with_daemon_level() {
        const panel = createTemporaryObject(panelComponent, testCase);
        const row = showRow(panel, {rssi: -62, rssi_kind: "dbm", signal_strength: 63,
            signal_level: 2, signal_live: true});
        tryCompare(row.value, "text", "63%");
        compare(row.icon.level, 2);
        compare(row.icon.iconColor, Ui.Theme.warning);
    }

    function test_missing_signal_hides_the_empty_meter() {
        const panel = createTemporaryObject(panelComponent, testCase);
        const row = showRow(panel, {rssi: null, signal_strength: null, signal_level: null, signal_live: false});
        tryCompare(row.value, "text", "—");
        compare(row.icon.level, 0);
        compare(row.icon.opacity, 0);
        verify(row.icon.width > 0, "the hidden meter keeps its column so rows stay aligned");
    }
}
