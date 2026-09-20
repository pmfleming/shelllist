import QtQuick
import QtTest
import Shelllist.Bluetooth as Bluetooth
import Shelllist.Io as Io

TestCase {
    id: tests
    name: "ProfileGaps"
    when: windowShown
    visible: true
    width: 800
    height: 650
    property var originalFactory
    property var originalSessions

    Component {
        id: offlineClient
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: false
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id: string, method: string, params: var): void {
            }
            function subscribeExtra(id: string, streams: var): void {
            }
            function release(id: string, route: var): void {}
            function cancel(id: string, requestId: string): void {
            }
        }
    }

    function initTestCase(): void {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = offlineClient;
    }

    function cleanupTestCase(): void {
        for (const name of Object.keys(Io.DaemonSessions.sessions))
            Io.DaemonSessions.sessions[name].client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }

    Component {
        id: bluetoothFactory
        Bluetooth.BluetoothController {}
    }

    function createView(file: string, properties: var): var {
        const component = Qt.createComponent("../../qml/Shelllist/" + file);
        compare(component.status, Component.Ready, component.errorString());
        const view = createTemporaryObject(component, tests, properties);
        verify(view !== null);
        return view;
    }

    function test_adapterSwitchClearsDrafts(): void {
        const controller = createTemporaryObject(bluetoothFactory, tests);
        controller.adapters = [
            {
                key: "first",
                alias: "First"
            },
            {
                key: "second",
                alias: "Second"
            }
        ];
        controller.preferredAdapterKey = "first";
        const view = createView("Bluetooth/BluetoothAdapterSettings.qml", {
            controller: controller,
            width: 700
        });
        wait(0);
        view.setDirty("alias", true);
        verify(view.hasDirtyFields);
        controller.preferredAdapterKey = "second";
        view.syncAdapterFields(false);
        compare(view.displayedAdapterKey, "second");
        verify(!view.hasDirtyFields);
        verify(view.aliasValid);
        view.destroy();
    }

    function test_batteryArtworkLoadsWithoutBlockingCreation(): void {
        const view = createView("Bluetooth/BluetoothBatteryStatus.qml", {
            width: 320,
            height: 180,
            device: {
                device_type: "mouse",
                battery_live: true,
                battery: [
                    {
                        component: "main",
                        percentage: 70
                    }
                ]
            }
        });
        const image = findChild(view, "batteryArtwork-main");
        verify(image !== null);
        verify(image.asynchronous);
        tryCompare(image, "status", Image.Ready);
        verify(view.implicitHeight > 0);
    }

    function test_solarProgressTracksClockAndMissingData(): void {
        const sunrise = Date.UTC(2026, 0, 1, 6);
        const sunset = Date.UTC(2026, 0, 1, 18);
        const view = createView("Activity/TimeWeatherTimePane.qml", {
            width: 760,
            height: 600,
            city: {
                label: "Test",
                utc_offset_seconds: 0,
                lunar: { phase: "waning-gibbous", fraction: 0.6, illumination_percent: 90, approximate: true },
                weather: {
                    sunrise_unix_ms: sunrise,
                    sunset_unix_ms: sunset,
                    solar_noon: { unix_ms: sunrise + 7 * 3600000, utc_offset_seconds: 0, approximate: true }
                }
            },
            now: new Date((sunrise + sunset) / 2)
        });
        verify(view.hasSunTimes);
        compare(view.sunProgress, 0.5);
        compare(view.solarNoon, sunrise + 7 * 3600000, "no QML midpoint calculation");
        compare(view.moon.fraction, 0.6);
        compare(view.moonName(view.moon.phase), "Waning gibbous");
        view.now = new Date(sunset + 3600000);
        compare(view.sunProgress, 1);
        compare(view.moon.fraction, 0.6, "clock ticks do not recompute astronomy");
        view.city = {
            label: "No forecast"
        };
        verify(!view.hasSunTimes);
        compare(view.solarNoon, 0);
        compare(view.moon, null);
        compare(view.time(0), "—");
    }
}
