pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io

DaemonTestCase {
    id: testCase
    name: "NativeWorkArea"
    Component {
        id: areaFactory
        Io.HyprlandWorkAreaClient {
            active: true
            monitorName: "eDP-1"
        }
    }
    function test_consumesNativeInsetsWithoutPollingAndClearsOnDisconnect() {
        const area = createTemporaryObject(areaFactory, testCase);
        verify(area !== null);
        wait(0);
        const backend = findChild(area, "workAreaBackend");
        const value = {
            available: true,
            revision: 1,
            monitors: {
                "eDP-1": {
                    left: 2,
                    top: 53,
                    right: 2,
                    bottom: 2
                },
                "DP-1": {
                    left: 26,
                    top: 82,
                    right: 12,
                    bottom: 22
                }
            }
        };
        backend.acceptSharedResponse("work-area-snapshot", {
            protocol: "bar-api",
            version: 1,
            ok: true,
            data: {
                snapshot: {
                    workarea: value
                }
            }
        }, "");
        compare(area.insets.top, 53);
        verify(area.ready);
        const requests = calls.length;
        area.monitorName = "DP-1";
        compare(area.insets.top, 82);
        wait(1100);
        compare(calls.length, requests, "no frontend geometry polling");
        backend.acceptSharedEvent({
            protocol: "bar-api",
            version: 1,
            stream: "workarea.changed",
            event: "lagged"
        });
        compare(calls.length, requests + 1, "the shared gap signal must recover geometry");
        compare(calls[calls.length - 1].method, "bar.snapshot");
        backend.failSharedTransport("Disconnected");
        compare(area.insets, null);
        verify(area.ready, "unavailable geometry permits the bounded screen fallback");
        area.active = false;
        area.apply(value);
        compare(area.insets, null, "hidden consumers ignore late data");
    }
}
