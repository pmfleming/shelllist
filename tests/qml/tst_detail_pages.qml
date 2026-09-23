pragma ComponentBehavior: Bound

import QtQuick
import "../../bluetooth" as Bluetooth
import "../../launcher" as Launcher
import "../../wifi" as Wifi

DaemonTestCase {
    id: testCase
    name: "DetailPages"
    when: windowShown
    visible: true
    width: 800
    height: 700
    clientReady: false

    // Representative consumers of DetailFlickable: dynamic resource cards,
    // adapter settings and fixed-height network cards. Shared layout behavior
    // belongs to tst_detail_layout; domain recovery tests construct other pages.
    Component {
        id: resourcesFactory
        Launcher.ApplicationResourcesPage {
            controller: Launcher.ApplicationController {}
            application: ({})
            uiScale: 1
        }
    }
    Component {
        id: adapterFactory
        Bluetooth.BluetoothAdapterPage {
            controller: Bluetooth.BluetoothController {}
        }
    }
    Component {
        id: networkFactory
        Wifi.NetworkDetailCards {
            controller: Wifi.WifiController {
                prompt: Wifi.WifiPromptController {}
            }
            accessPoint: ({})
            sectionSpacing: 12
            connectionCardHeight: 260
            networkCardHeight: 190
            profileCardHeight: 220
        }
    }

    function init() {
        failOnWarning(/.*(Column.*will not function|anchors.*layout|Binding loop).*/i);
    }

    function test_tabsStackAndResize_data() {
        return [
            { tag: "application-resources", factory: resourcesFactory },
            { tag: "bluetooth-adapter", factory: adapterFactory },
            { tag: "wifi-network", factory: networkFactory }
        ];
    }

    function verifyStack(page) {
        tryVerify(function () {
            let bottom = 0;
            let count = 0;
            for (const item of page.cards) {
                if (!item.visible || item.height <= 0 || item.width <= 0)
                    continue;
                if (Math.abs(item.y - bottom - (count > 0 ? page.cardSpacing : 0)) > 1)
                    return false;
                if (item.width > page.width + 1)
                    return false;
                bottom = item.y + item.height;
                ++count;
            }
            return count > 0 && Math.abs(page.contentHeight - bottom) <= 1;
        }, 1000, "tab sections must stay ordered, fit horizontally, and contribute to the scroll extent");
    }

    function test_tabsStackAndResize(data) {
        const page = createTemporaryObject(data.factory, testCase, {
            width: 675,
            height: 500
        });
        verify(page !== null);
        verifyStack(page);
        if (data.tag === "bluetooth-adapter") {
            page.controller.applySnapshot({
                radio: { available: true, operational: true, powered: true, adapter_count: 1 },
                adapters: [{ key: "adapter", alias: "Adapter", powered: true }],
                devices: []
            });
        } else if (data.tag === "application-resources") {
            page.application = { running: true, name: "Application" };
        }
        for (const width of [675, 320, 480]) {
            page.width = width;
            page.height = width / 2;
            verify(waitForRendering(page));
            verifyStack(page);
            compare(page.interactive, page.contentHeight > page.height);
            // Tabs are kept warm or loaded while hidden; both must lay out on return.
            page.visible = false;
            page.width = width + 20;
            page.visible = true;
            verifyStack(page);
        }
    }
}
