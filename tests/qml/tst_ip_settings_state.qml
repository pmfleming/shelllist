import QtQuick
import QtTest

TestCase {
    name: "IpSettingsState"

    property var ipState

    function initTestCase() {
        const component = Qt.createComponent(Qt.resolvedUrl("../../wifi/IpSettingsState.qml"));
        compare(component.status, Component.Ready, component.errorString());
        ipState = component.createObject(null, { family: "ipv4", fallbackPrefix: 24 });
        verify(ipState !== null);
    }

    function cleanupTestCase() { if (ipState) ipState.destroy(); }

    function init() {
        ipState.sync({ method: "auto", addresses: [], dns: [], dns_search: [] });
    }

    function test_synchronizesAndBuildsManualPayload() {
        ipState.sync({
            method: "manual",
            addresses: [{ address: "192.168.1.20", prefix: 24 }],
            gateway: "192.168.1.1",
            ignore_auto_dns: true,
            dns: ["1.1.1.1", "8.8.8.8"],
            dns_search: ["example.test"],
            routes: [{ destination: "10.0.0.0/8" }],
            route_metric: 50
        });
        verify(ipState.ready());
        const payload = ipState.payload({
            routes: [{ destination: "10.0.0.0/8" }], route_metric: 50
        });
        compare(payload.addresses[0].address, "192.168.1.20");
        compare(payload.addresses[0].prefix, 24);
        compare(payload.dns.length, 2);
        compare(payload.dns_search[0], "example.test");
        compare(payload.route_metric, 50);
    }

    function test_automaticDnsCanBeDisabledAndReenabled() {
        ipState.setAutoDns(false);
        verify(ipState.payload({}).ignore_auto_dns);
        ipState.setAutoDns(true);
        verify(!ipState.payload({}).ignore_auto_dns);
    }

    function test_rejectsIncompleteManualAddress() {
        ipState.method = "manual";
        ipState.address = "192.168.1";
        ipState.prefix = "24";
        verify(!ipState.ready());
    }
}
