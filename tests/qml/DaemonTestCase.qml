pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io

// Domain tests share a recording transport; routing/generation behavior is
// exercised separately by tst_daemon_sessions and check-daemon-boundary.js.
TestCase {
    id: testCase

    property bool clientReady: true
    property var calls: []
    property var originalFactory
    property var originalSessions

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: testCase.clientReady
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            function call(id, method, params, route) {
                testCase.calls = testCase.calls.concat([{id: id, method: method, params: params}]);
            }
            function subscribeExtra(id, streams, route) {}
            function cancel(id, requestId, route) {}
            function release(id, route) {}
        }
    }

    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }
    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions))
            session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }
}
