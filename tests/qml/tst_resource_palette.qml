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
        history.controller.resourceHistorySummary = {
            metrics: {
                cpu_percent_of_machine: {
                    available: true,
                    mean: 17.5,
                    peak: 40,
                    observed_ms: 4000,
                    coverage: 1
                }
            }
        };
        compare(history.average("cpu_percent_of_machine"), 17.5, "consume the daemon's weighted mean, not a sample mean");
        compare(history.peak("cpu_percent_of_machine", false), 40);
        compare(history.peak("cpu_percent_of_machine", true), 40);
        compare(history.average("memory_bytes"), 0);
    }
}
