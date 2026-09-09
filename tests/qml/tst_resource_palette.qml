import QtQuick
import QtTest
import Shelllist.Launcher as Launcher

TestCase {
    name: "ResourceHistory"

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
    }
}
