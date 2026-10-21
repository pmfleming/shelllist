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
    function test_nativeBufferLimitAndInvalidPairNeverDispatch() {
        const panel = make();
        const address = browse(panel, "wifiIpAddress");
        verify(address instanceof Ui.IpField);
        compare(findChild(panel, "wifiIpPrefix"), null, "subnet is not another Tab stop");
        keyClick(Qt.Key_Return);
        paste("192.168.1.20" + " ".repeat(IpValidation.MaximumEditingLength) + "/24");
        compare(address.text, "192.168.1.20/24", "oversized paste is rejected, not clipped");
        paste("192.168.1.20/" + "24".padEnd(IpValidation.MaximumEditingLength));
        compare(address.text, "192.168.1.20/24");
        paste("192.168.1.20/33");
        compare(address.validationState, IpValidation.Invalid);
        keyClick(Qt.Key_Tab);
        compare(panel.currentTarget.objectName, "wifiIpGateway");
        verify(panel.editing);
        compare(panel.page.currentIp.addressWithSubnet, "192.168.1.20/33");
        verify(!panel.page.hardwareSettingsReady());
        panel.page.saveDirty();
        compare(updates().length, 0);
        keyClick(Qt.Key_Escape);
        browse(panel, "wifiIpAddress");
        keyClick(Qt.Key_Return);
        paste("192.168.1.20");
        keyClick(Qt.Key_Return);
        verify(!panel.page.hardwareSettingsReady(), "bare paste cannot reuse the old subnet");
        panel.page.saveDirty();
        compare(updates().length, 0);
    }
    function test_combinedSaveIsAtomic_data() {
        return [
            {tag: "ipv4", family: "ipv4", value: "192.0.2.119/255.255.254.0", address: "192.0.2.119", prefix: 23},
            {tag: "ipv6", family: "ipv6", value: "2001:db8::119/96", address: "2001:db8::119", prefix: 96}
        ];
    }
    function test_combinedSaveIsAtomic(data) {
        const panel = make();
        panel.page.ipFamily = data.family;
        const address = browse(panel, "wifiIpAddress");
        const original = panel.page.currentIp.addressWithSubnet;
        keyClick(Qt.Key_Return);
        paste(data.value);
        compare(panel.page.currentIp.addressWithSubnet, original);
        compare(updates().length, 0);
        keyClick(Qt.Key_Return);
        panel.page.saveDirty();
        compare(updates().length, 1);
        const saved = updates()[0].params.settings[data.family];
        compare(saved.addresses, [{address: data.address, prefix: data.prefix}]);
        verify(panel.controller.advanced.saving, "the field cannot acknowledge the operation");
    }
    function test_familyChangeAndAutomaticValuesCannotSaveDrafts() {
        const panel = make();
        const address = browse(panel, "wifiIpAddress");
        keyClick(Qt.Key_Return);
        paste("192.0.2.1/32");
        panel.page.ipFamily = "ipv6";
        compare(panel.page.currentIp.addressWithSubnet, "2001:db8::20/64");
        compare(address.text, "2001:db8::20/64");
        verify(!panel.editing);
        compare(updates().length, 0);
        panel.page.currentIp.method = "auto";
        verify(address.readOnly);
        verify(!panel.availableFields().includes(address));
        panel.page.ipFamily = "ipv4";
        compare(address.text, "192.168.1.20/24");
        compare(updates().length, 0);
    }
    function test_gatewayAddressOnlyAndDnsTruncationGuard() {
        const panel = make();
        const gateway = browse(panel, "wifiIpGateway");
        keyClick(Qt.Key_Return);
        paste("192.168.1.1/24");
        compare(gateway.text, "", "gateway must reject a subnet rather than discard its suffix");
        paste("192.168.999.1");
        keyClick(Qt.Key_Tab);
        compare(panel.page.currentIp.gateway, "192.168.999.1");
        panel.page.saveDirty();
        compare(updates().length, 0);
        compare(panel.currentTarget.objectName, "wifiDnsServers");
        paste("1.1.1.1".padEnd(IpValidation.MaximumEditingLength) + "/24");
        keyClick(Qt.Key_Return);
        verify(!panel.page.hardwareSettingsReady(), "DNS retains its independent full-buffer guard");
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
