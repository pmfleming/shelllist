pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "NativeWorkArea"
    property var originalFactory
    property var originalSessions
    property var calls: []
    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id, method, params) { testCase.calls = testCase.calls.concat([method]); }
            function subscribeExtra(id, streams) {}
            function cancel(id, requestId) {}
            function release(id, route) {}
        }
    }
    Component { id: areaFactory; Io.HyprlandWorkAreaClient { active: true; monitorName: "eDP-1" } }
    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }
    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions)) session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }
    function test_consumesNativeInsetsWithoutPollingAndClearsOnDisconnect() {
        const area = createTemporaryObject(areaFactory, testCase);
        verify(area !== null);
        wait(0);
        const backend = findChild(area, "workAreaBackend");
        const value = { available: true, revision: 1, monitors: {"eDP-1": {left: 2, top: 53, right: 2, bottom: 2}, "DP-1": {left: 26, top: 82, right: 12, bottom: 22}} };
        backend.eventReceived({stream: "workarea.changed", event: "changed", data: value});
        compare(area.insets.top, 53);
        verify(area.ready);
        const requests = calls.length;
        area.monitorName = "DP-1";
        compare(area.insets.top, 82);
        wait(1100);
        compare(calls.length, requests, "no frontend geometry polling");
        backend.failSharedTransport("Disconnected");
        compare(area.insets, null);
        verify(area.ready, "unavailable geometry permits the bounded screen fallback");
        area.active = false;
        area.apply(value);
        compare(area.insets, null, "hidden consumers ignore late data");
    }
}
