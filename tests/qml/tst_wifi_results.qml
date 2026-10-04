import QtQuick
import "../../wifi" as Wifi

DaemonTestCase {
    id: testCase
    name: "WifiResults"

    Component {
        id: controllerFactory
        Wifi.WifiController {
            prompt: Wifi.WifiPromptController {}
        }
    }

    function test_subtitleShowsBandInsteadOfRepeatingSignalStrength() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        const network = {
            key: "network", ssid: "Yves New WIFI", strength: 77,
            band: "5 GHz", frequency: 5180, security: "WPA2/3"
        };
        const result = controller.provider.resultFor(network);
        compare(result.title, network.ssid);
        compare(result.subtitle, "5 GHz · WPA2/3");
        compare(result.payload.strength, 77, "the separate signal indicator retains its value");

        delete network.band;
        network.frequency = 2412;
        compare(controller.provider.resultFor(network).subtitle, "2.4 GHz · WPA2/3");
        network.frequency = 0;
        compare(controller.provider.resultFor(network).subtitle, "Unknown · WPA2/3");
    }
}
