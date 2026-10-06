pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Shelllist.Ui as Ui
import "../../wifi" as Wifi
import "../../wifi/networkinput" as NetworkInput
import "../qml" as Tests

// Explicitly invoked capture fixture. Synthetic values, recording daemon only.
Tests.DaemonTestCase {
    id: tests
    name: "FormVisualReview"
    visible: true
    when: windowShown
    width: 1060
    height: 920
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_ACCENT: "#6750a4", SHELLLIST_NO_ANIMATIONS: "1"};
        calls = [];
    }
    function cleanup() {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = Qt.Unknown;
    }
    Component {
        id: familyFactory
        Rectangle {
            width: tests.width
            height: 880
            color: Ui.Theme.window
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20
                Ui.ThemeText { text: "Form-field family · real Qt controls"; font.pixelSize: 24 }
                Ui.ChooserHeader { Layout.fillWidth: true; uiScale: 1; powerVisible: false; placeholder: "Search remains a capsule"; focusOnCompleted: false }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 20
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Device name"
                        Ui.TextField { Layout.fillWidth: true; text: "Studio headphones" }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Browsing"
                        Ui.TextField { Layout.fillWidth: true; text: "Only the editor is highlighted"; browseFocused: true }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Editing"
                        Ui.TextField { Layout.fillWidth: true; text: "A local draft"; focused: true }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "IPv4 address"
                        NetworkInput.IpAddressField { Layout.fillWidth: true; text: "192.168.300.20"; validationAttempted: true }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Network password · synthetic example"
                        Ui.TextField { Layout.fillWidth: true; text: "example-only"; password: true }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Refocus distance"
                        supportingText: "0–1000 logical pixels"
                        Ui.TextField { Layout.fillWidth: true; text: "30"; suffix: "px" }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Preferred adapter"
                        Ui.DropDownList { Layout.fillWidth: true; options: [{value: "builtin", label: "Built-in Bluetooth"}]; value: "builtin" }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Automatic address · read-only"
                        NetworkInput.IpAddressField { Layout.fillWidth: true; text: "2001:db8::20"; family: "ipv6"; readOnly: true }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "DNS servers"
                        NetworkInput.AddressListField { Layout.fillWidth: true; text: "2001:4860:4860::8888\n2606:4700:4700::1111"; family: "ipv6" }
                    }
                    Ui.FormField {
                        Layout.fillWidth: true
                        label: "Clipboard text"
                        Ui.TextEditor { Layout.fillWidth: true; text: "A native multiline editor.\nSelection, IME and scrolling stay native.\nShift+Enter inserts a newline." }
                    }
                }
                Ui.NotificationReplyRow {
                    Layout.fillWidth: true
                    notificationKey: "capture-only"
                    draftText: "Looks good, thank you."
                    onReplyRequested: tests.fail("Capture must not send replies")
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
    Component {
        id: networkFactory
        Rectangle {
            id: panel
            width: 620
            height: 900
            color: Ui.Theme.window
            property alias controller: controller
            property alias page: page
            Wifi.WifiController { id: controller; prompt: Wifi.WifiPromptController { } }
            Wifi.AdvancedSettingsPage { id: page; anchors.fill: parent; anchors.margins: 20; controller: panel.controller }
        }
    }
    function save(item, name) {
        wait(150);
        verify(waitForPolish(item.Window.window));
        const path = decodeURIComponent(Qt.resolvedUrl("../../target/form-field-implementation/").toString().replace(/^file:\/\//, ""));
        grabImage(item).save(path + name + ".png");
    }
    function test_capture_data() {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_capture(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const family = createTemporaryObject(familyFactory, tests);
        save(family, "family-" + data.tag);
        family.visible = false;
        const panel = createTemporaryObject(networkFactory, tests);
        panel.controller.advanced.open = true;
        panel.controller.advanced.section = "hardware";
        panel.controller.advanced.profilePath = "/org/freedesktop/NetworkManager/Settings/1";
        panel.controller.advanced.applyProfile({path: panel.controller.advanced.profilePath, version: "capture",
            ipv4: {method: "manual", addresses: [{address: "192.168.1.20", prefix: 24}], gateway: "192.168.1.1", ignore_auto_dns: true, dns: ["1.1.1.1", "8.8.8.8"]},
            ipv6: {method: "manual", addresses: [{address: "2001:db8::20", prefix: 64}], ignore_auto_dns: true, dns: ["2001:4860:4860::8888", "2606:4700:4700::1111"]}});
        save(panel, "ipv4-" + data.tag);
        panel.page.ipFamily = "ipv6";
        save(panel, "ipv6-" + data.tag);
        panel.width = 380;
        save(panel, "network-narrow-" + data.tag);
        compare(calls.filter(call => call.method !== "bar.snapshot").length, 0, "capture must never mutate a backend");
    }
}
