pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Wifi as Wifi
import "../../bluetooth" as Bluetooth
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "ListAlignment"
    when: windowShown
    visible: true
    width: 453
    height: 720

    Component {
        id: wifiPane
        Wifi.WifiContent {
            controller: Wifi.WifiController {
                prompt: Wifi.WifiPromptController {}
                uiActive: true
            }
            Component.onCompleted: {
                controller.applyNetworks([
                    {key: "a", ssid: "First network", strength: 65, security: "WPA2", frequency: 5200},
                    {key: "b", ssid: "Second network", strength: 45, security: "WPA2", frequency: 2412}
                ], true, null);
                controller.status = "Wi-Fi ready";
            }
        }
    }
    Component {
        id: bluetoothPane
        Bluetooth.BluetoothContent {
            controller: Bluetooth.BluetoothController { uiActive: true }
            Component.onCompleted: controller.applySnapshot({
                radio: {available: true, operational: true, powered: true, adapter_count: 1},
                adapters: [{key: "adapter", alias: "Adapter", powered: true}],
                devices: [{key: "a", name: "First device", paired: true, battery: [], services: []},
                          {key: "b", name: "Second device", paired: true, battery: [], services: []}]
            })
        }
    }
    Component {
        id: timePane
        Activity.TimeWeatherContent {
            controller: Activity.TimeWeatherController {
                uiActive: true
                activity: ({available: true, syncing: false, world_clocks: [
                    {timezone: "Europe/London", label: "London"},
                    {timezone: "Europe/Paris", label: "Paris"}
                ]})
            }
        }
    }
    function init(): void { failOnWarning(/.*/); testCase.height = 720; }
    function itemOfType(item, type) {
        if (item instanceof type) return item;
        for (const child of item.children) {
            const found = itemOfType(child, type);
            if (found) return found;
        }
        return null;
    }
    function test_searchResultsAndStatusShareEdges_data() {
        return [{tag: "wifi", factory: wifiPane},
                {tag: "bluetooth", factory: bluetoothPane},
                {tag: "time-weather", factory: timePane}];
    }
    function test_searchResultsAndStatusShareEdges(data) {
        const surface = createTemporaryObject(data.factory, testCase);
        verify(surface !== null);
        tryVerify(() => surface.listItem !== null);
        const pane = surface.listItem;
        const header = itemOfType(pane, Ui.ChooserHeader);
        const status = itemOfType(pane, Ui.StatusPanel);
        const list = findChild(pane, "resultListView");
        tryCompare(list, "count", 2);
        for (const height of [720, 360]) {
            testCase.height = height;
            verify(waitForPolish(pane.Window.window));
            compare(surface.height, height, "exercise the real anchored viewport, not an overridden item height");
            compare(pane.mapToItem(surface, 0, 0).x, surface.controller.contentMargin, "keep the single outer margin");
            verify(status.visible, "retain domain status rather than removing it to align the list");
            for (const item of [list, status]) {
                compare(item.mapToItem(pane, 0, 0).x, header.mapToItem(pane, 0, 0).x);
                compare(item.width, header.width);
            }
        }
        pane.focusSearch();
        keyClick(Qt.Key_Down);
        verify(pane.listFocused);
        const row = list.itemAtIndex(1);
        verify(row !== null);
        // The reclaimed strip belongs to the row's hit area, not dead space.
        mouseClick(row, 4, row.height / 2);
        compare(pane.selectedIndex, 1);
        const marker = findChild(row, "browseFocusIndicator");
        verify(marker.visible);
        const point = marker.mapToItem(list, 0, 0);
        verify(point.x >= 0 && point.x + marker.width <= list.width, "focus marker remains inside the clipped list");
        keyClick(Qt.Key_Up);
        compare(pane.selectedIndex, 0);
        keyClick(Qt.Key_Up);
        verify(pane.searchFocused, "native result navigation still returns to search");
    }
}
