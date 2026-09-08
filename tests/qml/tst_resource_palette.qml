import QtQuick
import QtTest
import "imports/Quickshell" as TestShell
import Shelllist.Ui as Ui
import Shelllist.Launcher as Launcher

TestCase {
    name: "ResourcePalette"
    property var savedEnvironment

    Component {
        id: historyFactory
        Launcher.ApplicationResourceHistory {
            width: 800
            uiScale: 1
            application: ({
                    running: false
                })
            controller: Launcher.ApplicationController {}
        }
    }

    function init(): void {
        savedEnvironment = TestShell.Quickshell.environment;
    }
    function cleanup(): void {
        TestShell.Quickshell.environment = savedEnvironment;
    }

    function test_lightDarkAndOverride(): void {
        const history = createTemporaryObject(historyFactory, this);
        TestShell.Quickshell.environment = {
            SHELLLIST_BG: "#ffffff"
        };
        compare(Ui.Theme.dark, false);
        compare(String(history.cpuColor), "#2563eb");
        compare(String(history.powerColor), "#be123c");
        TestShell.Quickshell.environment = {
            SHELLLIST_BG: "#000000"
        };
        compare(Ui.Theme.dark, true);
        compare(String(history.cpuColor), "#60a5fa");
        compare(String(history.powerColor), "#fb7185");
        TestShell.Quickshell.environment = {
            SHELLLIST_BG: "#000000",
            SHELLLIST_RESOURCE_CPU: "#123456"
        };
        compare(String(history.cpuColor), "#123456");
        compare(String(history.networkReceiveColor), String(Ui.Theme.resourceNetworkReceive));
    }

    function test_typedHistoryHelpersRespectAvailability(): void {
        const history = createTemporaryObject(historyFactory, this);
        history.controller.resourceHistory = [
            {
                cpu_percent_of_machine: 10,
                availability: {
                    cpu: true
                },
                peaks: {
                    cpu_percent_of_machine: 40
                }
            },
            {
                cpu_percent_of_machine: 20,
                availability: {
                    cpu: true
                }
            },
            {
                cpu_percent_of_machine: 100,
                availability: {
                    cpu: false
                }
            }
        ];
        compare(history.average("cpu_percent_of_machine"), 15);
        compare(history.peak("cpu_percent_of_machine", false), 20);
        compare(history.peak("cpu_percent_of_machine", true), 40);
        compare(history.average("memory_bytes"), 0);
        const descriptor = history.graphSeries("cpu_percent_of_machine", "", "CPU", history.cpuColor, "percent", 0);
        compare(descriptor.metric, "cpu_percent_of_machine");
        compare(String(descriptor.color), String(history.cpuColor));
    }
}
