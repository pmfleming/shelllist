pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io
import "../../qml/Shelllist/Activity" as Activity
import "../../bluetooth" as Bluetooth
import "../../clipboard" as Clipboard
import "../../launcher" as Launcher
import "../../wifi" as Wifi

TestCase {
    id: testCase
    name: "DetailPages"
    when: windowShown
    visible: true
    width: 800
    height: 700
    property var originalClientFactory
    property var originalSessions

    // Keep layout tests independent of daemon startup, subscriptions and retries.
    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: false
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id, method, params) {
            }
            function subscribeExtra(id, streams) {
            }
            function release(id, route) {}
            function cancel(id, requestId) {
            }
        }
    }

    function initTestCase() {
        originalClientFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }

    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions))
            session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalClientFactory;
    }

    Component {
        id: resourcesFactory
        Launcher.ApplicationResourcesPage {
            controller: Launcher.ApplicationController {}
            application: ({})
            uiScale: 1
        }
    }
    Component {
        id: settingsFactory
        Launcher.ApplicationSettingsPage {
            controller: Launcher.ApplicationController {}
            application: ({})
        }
    }
    Component {
        id: deviceFactory
        Bluetooth.BluetoothDevicePage {
            controller: Bluetooth.BluetoothController {}
        }
    }
    Component {
        id: informationFactory
        Bluetooth.BluetoothInformationPage {
            controller: Bluetooth.BluetoothController {}
        }
    }
    Component {
        id: adapterFactory
        Bluetooth.BluetoothAdapterPage {
            controller: Bluetooth.BluetoothController {}
        }
    }
    Component {
        id: clipboardFactory
        Clipboard.ClipboardDetailCards {
            controller: Clipboard.ClipboardController {}
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
    Component {
        id: weatherFactory
        Activity.ActivityWeatherPane {
            controller: Activity.ActivityController {}
            now: new Date(2026, 8, 11, 12)
        }
    }
    Component {
        id: timeFactory
        Activity.TimeWeatherTimePane {
            city: ({})
            now: new Date(2026, 8, 11, 12)
        }
    }

    function init() {
        failOnWarning(/.*(Column.*will not function|anchors.*layout|Binding loop).*/i);
    }

    function test_tabsStackAndResize_data() {
        return [
            {
                tag: "application-resources",
                factory: resourcesFactory
            },
            {
                tag: "application-settings",
                factory: settingsFactory
            },
            {
                tag: "bluetooth-device",
                factory: deviceFactory
            },
            {
                tag: "bluetooth-settings",
                factory: deviceFactory
            },
            {
                tag: "bluetooth-information",
                factory: informationFactory
            },
            {
                tag: "bluetooth-adapter",
                factory: adapterFactory
            },
            {
                tag: "bluetooth-adapter-pairing",
                factory: adapterFactory
            },
            {
                tag: "clipboard-details",
                factory: clipboardFactory
            },
            {
                tag: "wifi-network",
                factory: networkFactory
            },
            {
                tag: "weather",
                factory: weatherFactory
            },
            {
                tag: "time",
                factory: timeFactory
            }
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

    function populate(page, tag) {
        if (tag.startsWith("bluetooth-")) {
            page.controller.applySnapshot({
                radio: {
                    available: true,
                    operational: true,
                    powered: true,
                    adapter_count: 1
                },
                adapters: [
                    {
                        key: "adapter",
                        alias: "Adapter",
                        powered: true
                    }
                ],
                devices: [
                    {
                        key: "headset",
                        name: "Headset",
                        paired: true,
                        connected: true,
                        adapter_key: "adapter",
                        battery: [],
                        services: [
                            {
                                label: "Audio"
                            }
                        ],
                        policy: {},
                        capabilities: {}
                    }
                ]
            });
            page.controller.applyAudioSnapshot([
                {
                    device_key: "headset",
                    profiles: [],
                    sink: {
                        ready: true,
                        is_default: true
                    },
                    source: null
                }
            ]);
        } else if (tag === "clipboard-details") {
            page.controller.detailState.value = {
                entry: {
                    kind: "text"
                },
                files: [],
                text: "Clipboard text"
            };
        } else if (tag === "application-resources") {
            page.application = {
                running: true,
                name: "Application"
            };
        } else if (tag === "weather") {
            page.showLocationRail = false;
        }
    }

    function test_tabsStackAndResize(data) {
        const page = createTemporaryObject(data.factory, testCase, {
            width: 675,
            height: 500
        });
        verify(page !== null);
        verifyStack(page);
        populate(page, data.tag);
        if (data.tag === "bluetooth-settings")
            page.controller.detailsTab = "settings";
        if (data.tag === "bluetooth-adapter-pairing")
            page.controller.adapterSettingsTab = "pairing";
        for (const width of [675, 320, 480]) {
            page.width = width;
            page.height = width / 2;
            verify(waitForRendering(page)); // Settle wrapped text and nested layouts before measuring cards.
            verifyStack(page);
            const policy = findChild(page, "devicePolicy");
            if (policy) {
                compare(policy.visible, data.tag === "bluetooth-settings");
                if (policy.visible)
                    verify(policy.mapToItem(page.contentItem, 0, policy.height).y <= page.contentHeight + 1);
            }
            const technicalDetails = findChild(page, "adapterTechnicalDetails");
            if (technicalDetails && technicalDetails.visible) {
                for (const name of ["adapterControllerName", "adapterAddress", "adapterModalias"]) {
                    const field = findChild(technicalDetails, name);
                    verify(field !== null && field.visible);
                    verify(field.mapToItem(page.contentItem, 0, field.height).y <= page.contentHeight + 1);
                }
            }
            compare(page.interactive, page.contentHeight > page.height);
            // Tabs are kept warm or loaded while hidden; both must lay out on return.
            page.visible = false;
            page.width = width + 20;
            page.visible = true;
            verifyStack(page);
        }
    }
}
