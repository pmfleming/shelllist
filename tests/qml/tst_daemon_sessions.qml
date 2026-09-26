pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "DaemonSessions"
    when: windowShown

    property var originalFactory
    property var originalSessions
    property int received: 0
    property int page: 0
    property string queryId: ""
    property string consumerId: ""

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: true
            property string lastId: ""
            property var lastRoute: null
            property var calls: []
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            function call(id, method, params, route) {
                lastId = id;
                lastRoute = route;
                calls = calls.concat([
                    {
                        id: id,
                        route: route
                    }
                ]);
            }
            function subscribeExtra(id, streams, route) {
            }
            function cancel(id, requestId, route) {
            }
            function release(id, route) {
            }
        }
    }

    Component {
        id: backendFactory
        Io.DaemonBackend {
            daemonName: "stress-daemon"
            active: true
            onTransportReady: callSequenced("snapshot", "state.get", {})
        }
    }

    QtObject {
        id: consumer
        property string daemonName: "stress-daemon"
        property bool active: true
        property bool recoverProtocolErrors: true
        property var streams: []
        function acceptSharedResponse(id, envelope, error) {
            testCase.received += 1;
            testCase.page += 1;
            // Match the crash: register the next page while delivering a reply.
            if (testCase.page < 5)
                Io.DaemonSessions.call(daemonName, testCase.consumerId, testCase.queryId, "history.query", {
                    offset: testCase.page * 200
                });
        }
        function failSharedTransport(message) {
        }
    }

    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
        consumerId = Io.DaemonSessions.attach(consumer);
    }

    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions))
            session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }

    function test_attachToReadySession() {
        const session = Io.DaemonSessions.sessions[consumer.daemonName];
        session.client.calls = [];
        const backend = createTemporaryObject(backendFactory, testCase);
        verify(backend !== null);
        verify(backend.ready);
        compare(session.client.calls.length, 1, "startup must run once, after attachment");
        compare(session.client.calls[0].route.consumerId, backend.sharedConsumerId);
        verify(backend.sharedConsumerId.length > 0, "never send an empty bridge route");
        session.client.ready = false;
        session.client.ready = true;
        compare(session.client.calls.length, 2, "reconnect still refreshes the attached backend");
    }

    function test_paginatedRequestChurn() {
        const session = Io.DaemonSessions.sessions[consumer.daemonName];
        for (let generation = 0; generation < 4000; ++generation) {
            page = 0;
            queryId = "query-" + generation;
            Io.DaemonSessions.call(consumer.daemonName, consumerId, queryId, "history.query", {
                offset: 0
            });
            for (let index = 0; index < 5; ++index)
                session.client.response(session.client.lastId, {
                    ok: true,
                    data: {}
                }, "", session.client.lastRoute);
            session.client.calls = [];
            if (generation % 100 === 0)
                gc();
        }
        compare(received, 20000);
        verify(session.routes === undefined, "request routes must not accumulate in QML");
        verify(session.subscriptionOwners === undefined, "the Rust bridge owns subscription routing");
    }
}
