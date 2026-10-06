pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import "../../qml/Shelllist/Wifi" as Wifi
import "../../qml/Shelllist/Battery" as Battery
import "../../qml/Shelllist/Launcher" as Launcher
import "../qml" as Tests

// Focused captures of production sections, not HTML recreations. All controllers
// use DaemonTestCase's recording transport; no live daemon is contacted.
Tests.DaemonTestCase {
    id: tests
    name: "ExternalHeaderReview"
    when: windowShown
    visible: true
    width: 744
    height: 1100

    Rectangle {
        id: frame
        width: 724
        height: 900
        color: Ui.Theme.window
        clip: true
        Item { id: stage; x: 12; width: 700; height: 2200 }
    }
    Ui.DetailsNavigation { id: navigation }
    Component {
        id: wifiFactory
        Item {
            width: 700; height: 1800
            property alias controller: controller
            Wifi.WifiController { id: controller; prompt: Wifi.WifiPromptController {} }
            Wifi.AdvancedSettingsPage {
                width: parent.width; height: parent.height
                controller: controller
            }
        }
    }
    Component {
        id: networkFactory
        Wifi.NetworkDetailCards {
            width: 700; height: 1600
            controller: Wifi.WifiController { prompt: Wifi.WifiPromptController {} }
            accessPoint: ({ssid: "Review network", strength: 90, security: "wpa2", active: true})
            sectionSpacing: 12
            connectionCardHeight: 260
            networkCardHeight: 180
        }
    }
    Component {
        id: careFactory
        Battery.BatteryCarePane {
            controller: Battery.BatteryController {}
            battery: ({available: true, plugged: true, devices: []})
            device: ({id: "BAT0", energy_now_wh: 42, energy_full_wh: 54, energy_full_design_wh: 60, serial: "REVIEW-001"})
            protection: ({enabled: false})
        }
    }
    Component {
        id: powerFactory
        Battery.PowerControlsPane {
            controller: Battery.BatteryController {
                Component.onCompleted: applyPowerProfile({available: true, profile: "balanced", battery_aware: true, actions: [{name: "panel_power", description: "Reduce panel power use", enabled: true}]})
            }
        }
    }
    Component {
        id: resourcesFactory
        Launcher.ApplicationResourceHistory {
            width: 700
            controller: Launcher.ApplicationController {}
            application: ({running: true})
            uiScale: 1
        }
    }
    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign).*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "1", SHELLLIST_ACCENT: "#6750a4"};
        Ui.Theme.previewColorScheme = Qt.Dark;
        stage.y = 0;
        frame.height = 900;
        calls = [];
    }
    function cleanup() {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = Qt.Unknown;
        verify(!calls.some(call => /\.(set|connect$|disconnect$|commit|invoke|preview|confirm|reply|dismiss|launch|activate|rename|update)/.test(call.method)), "Captures must not dispatch mutations");
    }
    function capture(item, top, height, filename) {
        verify(item !== null);
        wait(100);
        const point = item.mapToItem(stage, 0, top);
        stage.y = 12 - point.y;
        frame.height = Math.ceil(height + 24);
        verify(frame.height <= tests.height, "Capture must fit the review window");
        wait(100);
        verify(waitForPolish(frame.Window.window));
        const directory = decodeURIComponent(Qt.resolvedUrl("../../target/external-header-removal/").toString().replace(/^file:\/\//, ""));
        let saved = false;
        verify(frame.grabToImage(result => { saved = result.saveToFile(directory + filename + ".png"); }));
        tryVerify(() => saved);
    }
    function test_sections_data() {
        return [
            {tag: "wifi-device-dhcp", factory: wifiFactory, name: "wifiSecurityDiagnostics"},
            {tag: "wifi-connection-network", factory: networkFactory, name: "wifiNetworkDiagnostics"},
            {tag: "battery-hardware", factory: careFactory, name: "batteryHardwareDetails"},
            {tag: "battery-automation", factory: powerFactory, name: "batteryAutomationSection"}
        ];
    }
    function test_sections(data) {
        const pane = createTemporaryObject(data.factory, stage);
        verify(pane !== null);
        if (data.tag === "wifi-device-dhcp") pane.controller.advanced.section = "security";
        const section = findChild(pane, data.name);
        tryVerify(() => section !== null && section.visible && section.height > 0);
        wait(100);
        verify(waitForPolish(frame.Window.window));
        compare(section.title, "");
        const body = section.children[1];
        compare(body.y, 0, "hidden heading must not leave a top gap");
        const cards = Array.from(body.children).filter(child => child instanceof Ui.DetailCard && child.visible);
        verify(cards.length > 0);
        verify(cards.every(card => card.title.length > 0), "internal titles are retained");
        compare(cards[0].mapToItem(section, 0, 0).y, 0);
        if (data.tag === "battery-automation") {
            verify(findChild(pane, "batteryHardwareTuningCard").visible);
            verify(!section.informationOnly);
            verify(navigation.collectTargets(section).length > 0, "automation fields remain reachable");
        } else {
            verify(section.informationOnly);
            compare(navigation.collectTargets(section).length, 0, "diagnostics remain outside field traversal");
        }
        capture(section, 0, section.height, data.tag);
    }
    function test_application_resources() {
        const pane = createTemporaryObject(resourcesFactory, stage);
        verify(pane !== null);
        wait(100);
        const children = Array.from(pane.children).filter(child => child.visible && child.height > 0);
        compare(children.length, 3); // capacity cards, range-only row, chart
        compare(children[0].y, 0, "removed composition heading leaves no top gap");
        compare(children[2].title, "Shared timeline");
        compare(navigation.collectTargets(pane).length, 1, "only the range selector joins field traversal");
        capture(pane, 0, children[0].y + children[0].height, "applications-composition");
        capture(pane, children[1].y, children[2].y + children[2].height - children[1].y, "applications-activity");
    }
}
