pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io

// Domain tests share a recording transport; routing/generation behavior is
// exercised separately by tst_daemon_sessions and tst_daemon_boundary (cargo xtask check-daemon-boundary).
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
            property var subscriptions: []
            property var cancellations: []
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            function call(id, method, params, route) {
                testCase.calls = testCase.calls.concat([
                    {
                        id: id,
                        method: method,
                        params: params,
                        route: route
                    }
                ]);
            }
            function subscribeExtra(id, streams, route) {
                subscriptions = subscriptions.concat([{id: id, streams: streams, route: route}]);
            }
            function cancel(id, requestId, route) {
                cancellations = cancellations.concat([requestId]);
            }
            function release(id, route) {
            }
        }
    }

    // Bind producer fixture data to an acknowledged live subscription. The
    // native bridge buffers pre-ack events; domain mocks must respect that too.
    function emitBaseEvent(daemonName, route, envelope) {
        const session = Io.DaemonSessions.sessions[daemonName];
        const consumer = session.consumers[route.consumerId];
        if (!consumer.baseSubscriptionId) {
            const request = session.client.subscriptions.find(r => r.id === consumer.baseSubscriptionRequestId);
            verify(request !== undefined, "base subscription requested before event delivery");
            session.client.response(request.id, {ok: true, data: {subscription: {id: "fixture-" + request.id}}}, "", request.route);
        }
        session.client.eventReceived(Object.assign({}, envelope, {subscription_id: consumer.baseSubscriptionId}), route);
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
