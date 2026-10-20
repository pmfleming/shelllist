pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "../../wifi" as Wifi
import "../../wifi/networkinput/IpValidation.js" as IpValidation

DaemonTestCase {
    id: tests
    name: "IpFields"
    when: windowShown
    visible: true
    width: 720
    height: 760

    Component {
        id: factory
        Ui.PanelSurface {
            id: navigation
            anchors.fill: undefined
            width: tests.width
            height: tests.height
            property alias controller: controller
            property alias page: page
            navigationContent: page
            chooserController: Ui.ChooserController { uiActive: true }
            readonly property Item currentTarget: detailsNavigation.currentTarget
            readonly property bool editing: detailsNavigation.editing
            function focusContent(reset: bool): void { detailsNavigation.focusContent(reset); }
            function availableFields(): var { return detailsNavigation.availableFields(); }
            Wifi.WifiController {
                id: controller
                prompt: Wifi.WifiPromptController { }
            }
            Wifi.AdvancedSettingsPage {
                id: page
                anchors.fill: parent
                controller: navigation.controller
            }
        }
    }
    TextEdit {
        id: clipboardSource
        visible: false
    }
    function init() { failOnWarning(/.*/); calls = []; }
    function make() {
        const panel = createTemporaryObject(factory, tests);
        panel.controller.advanced.open = true;
        panel.controller.advanced.section = "hardware";
        panel.controller.advanced.profilePath = "/org/freedesktop/NetworkManager/Settings/1";
        panel.controller.advanced.applyProfile({
            path: panel.controller.advanced.profilePath, version: "test-version",
            security_type: "WPA2 Personal", mac_address_policy: "default",
            ipv4: {method: "manual", addresses: [{address: "192.168.1.20", prefix: 24}], ignore_auto_dns: true, dns: [],
                dns_search: ["example.test"], routes: [{destination: "10.0.0.0/8"}], route_metric: 50},
            ipv6: {method: "manual", addresses: [{address: "2001:db8::20", prefix: 64}], ignore_auto_dns: true, dns: []}
        });
        tryVerify(() => findChild(panel, "wifiIpAddress") !== null);
        panel.focusContent(true);
        calls = [];
        return panel;
    }
    function browse(panel, name) {
        for (let i = 0; i < 15 && panel.currentTarget.objectName !== name; i++)
            keyClick(Qt.Key_Tab);
        compare(panel.currentTarget.objectName, name);
        return panel.currentTarget;
    }
    function paste(value) {
        clipboardSource.text = value;
        clipboardSource.selectAll();
        clipboardSource.copy();
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_V, Qt.ControlModifier);
    }
    function updates() {
        return calls.filter(call => call.method === "wifi.profile.operation" && call.params.operation === "update");
    }
    function test_nativeBufferLimitAndPrefixPasteNeverBecomeValidTruncations() {
        const panel = make();
        const address = browse(panel, "wifiIpAddress");
        keyClick(Qt.Key_Return);
        paste("192.168.1.20" + " ".repeat(IpValidation.MaximumEditingLength) + "/24");
        compare(address.text.length, IpValidation.MaximumEditingLength);
        compare(address.validationState, IpValidation.Invalid);
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Tab);
        const prefix = panel.currentTarget;
        compare(prefix.objectName, "wifiIpPrefix");
        keyClick(Qt.Key_Return);
        paste("24".padEnd(IpValidation.MaximumEditingLength));
        compare(prefix.validationState, IpValidation.Invalid);
        compare(prefix.errorText, "");
        keyClick(Qt.Key_Return);
        verify(prefix.errorText.includes("too long"));
        keyClick(Qt.Key_Return);
        paste("3200");
        compare(prefix.text, "3200");
        keyClick(Qt.Key_Return);
        verify(prefix.errorText.includes("0 to 32"));
        panel.page.saveDirty();
        compare(updates().length, 0);
    }
    function test_dnsMultilineTransactionAndAcknowledgementBoundary() {
        const panel = make();
        const field = browse(panel, "wifiDnsServers");
        verify(field instanceof Ui.TextEditor);
        compare(findChild(field, "multilineInput").Accessible.name, "DNS servers");
        keyClick(Qt.Key_Return);
        paste("1.1.1.1");
        keyClick(Qt.Key_Return, Qt.ShiftModifier);
        clipboardSource.text = "8.8.8.8";
        clipboardSource.selectAll();
        clipboardSource.copy();
        keyClick(Qt.Key_V, Qt.ControlModifier);
        compare(field.text, "1.1.1.1\n8.8.8.8");
        compare(panel.page.currentIp.dns, "");
        compare(updates().length, 0);
        keyClick(Qt.Key_Return);
        compare(panel.page.currentIp.dns, field.text);
        panel.page.saveDirty();
        compare(updates().length, 1);
        const saved = updates()[0].params.settings.ipv4;
        compare(saved.dns, ["1.1.1.1", "8.8.8.8"]);
        compare(saved.addresses, [{address: "192.168.1.20", prefix: 24}]);
        compare(saved.dns_search, ["example.test"]);
        compare(saved.routes, [{destination: "10.0.0.0/8"}]);
        compare(saved.route_metric, 50, "editing DNS cannot overwrite unrelated routing settings");
        verify(saved.ignore_auto_dns);
        verify(panel.controller.advanced.saving, "submitting is not acknowledgement");
    }
}
