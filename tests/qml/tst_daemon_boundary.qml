pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io
import "../../qml/Shelllist/Io/JsonlRouting.js" as Routing

// Runs the actual QML consumer/session objects. Only the process transport is fake.
TestCase {
    id: tests
    name: "DaemonBoundary"
    when: windowShown
    property var originalFactory
    property var originalSessions
    property var views: []
    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: true
            property var subscriptions: []
            property var cancellations: []
            property var recoveries: []
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            function subscribeExtra(id, streams, route) {
                subscriptions = subscriptions.concat([
                    {
                        id: id,
                        streams: streams,
                        route: route
                    }
                ]);
            }
            function cancel(id, requestId, route) {
                cancellations = cancellations.concat([requestId]);
            }
            function call(id, method, params, route) {
            }
            function release(id, route) {
            }
            function recover(message) {
                recoveries = recoveries.concat([message]);
                transportFailed(message);
            }
        }
    }
    Component {
        id: backendFactory
        Io.DaemonBackend {
            daemonName: "boundary-test"
            active: false
            expectedProtocol: "test-api"
            expectedVersion: 1
            property int replies: 0
            property int events: 0
            property int gaps: 0
            onResponseReceived: replies++
            onEventReceived: events++
            onEventGapDetected: gaps++
        }
    }
    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.clientFactory = clientFactory;
        Io.DaemonSessions.sessions = ({});
    }
    function cleanup() {
        for (const view of views)
            if (view)
                view.destroy();
        views = [];
        wait(0);
        for (const session of Object.values(Io.DaemonSessions.sessions))
            session.client.destroy();
        Io.DaemonSessions.sessions = ({});
        wait(0);
    }
    function cleanupTestCase() {
        Io.DaemonSessions.clientFactory = originalFactory;
        Io.DaemonSessions.sessions = originalSessions;
    }
    function fixture() {
        const resident = backendFactory.createObject(tests) as Io.DaemonBackend;
        const view = backendFactory.createObject(tests, {
            streams: ["updates"]
        }) as Io.DaemonBackend;
        verify(resident !== null && view !== null);
        views = [resident, view];
        resident.active = true;
        const session = Io.DaemonSessions.sessions[view.daemonName];
        return {
            resident: resident,
            view: view,
            id: view.sharedConsumerId,
            session: session,
            client: session.client
        };
    }
    function requests(f) {
        return f.client.subscriptions.filter(s => s.route.consumerId === f.id);
    }
    function reply(f, request, id) {
        f.client.response(request.id, {
            ok: true,
            data: {
                subscription: {
                    id: id
                }
            }
        }, "", request.route);
    }
    function test_pendingReopenAdoptsAndClosedRepliesCancel() {
        const f = fixture();
        f.view.active = true;
        f.view.active = false;
        f.view.active = true;
        compare(requests(f).length, 1);
        reply(f, requests(f)[0], "adopted");
        f.view.active = false;
        f.view.active = true;
        const next = requests(f)[1];
        f.view.active = false;
        reply(f, next, "closed");
        compare(f.client.cancellations, ["adopted", "closed"]);
    }
    function test_extraSubscriptionsCancelByDaemonId_data() {
        return [
            {
                tag: "before-reply",
                early: true
            },
            {
                tag: "after-reply",
                early: false
            }
        ];
    }
    function test_extraSubscriptionsCancelByDaemonId(data) {
        const f = fixture();
        f.view.active = true;
        const id = f.view.subscribeStreams(["updates"]);
        const request = requests(f).find(r => r.route.localId === id);
        verify(request !== undefined);
        if (data.early)
            verify(f.view.unsubscribeStreams(id));
        reply(f, request, "extra-daemon-id");
        if (!data.early)
            verify(f.view.unsubscribeStreams(id));
        compare(f.client.cancellations, ["extra-daemon-id"]);
        compare(f.view.replies, 0);
    }
    function test_detachedPendingRepliesAreCancelledWithResidentStillAlive() {
        const f = fixture();
        f.view.active = true;
        f.view.subscribeStreams(["updates"]);
        const pending = requests(f);
        compare(pending.length, 2);
        views = [f.resident];
        f.view.destroy();
        wait(0);
        verify(f.client.active);
        reply(f, pending[0], "detached-base");
        reply(f, pending[1], "detached-extra");
        compare(f.client.cancellations, ["detached-base", "detached-extra"]);
    }
    function test_generationFencesAndEventOwnership() {
        const f = fixture();
        f.view.active = true;
        const old = requests(f)[0];
        const event = {
            protocol: "test-api",
            version: 1,
            stream: "updates",
            event: "changed",
            data: {},
            subscription_id: "owned"
        };
        f.client.eventReceived(event, old.route);
        compare(f.view.events, 0, "unacknowledged subscriptions cannot deliver state");
        reply(f, old, "owned");
        f.client.eventReceived(event, old.route);
        f.client.eventReceived(event, Object.assign({}, old.route, {
            consumerId: "missing"
        }));
        f.client.eventReceived(event, null);
        compare(f.view.events, 1);
        f.client.transportFailed("lost transport");
        Io.DaemonSessions.restoreSubscriptions("boundary-test");
        f.client.eventReceived(event, old.route);
        compare(f.view.events, 1);
        reply(f, old, "old-generation");
        reply(f, requests(f)[1], "new-generation");
        f.view.active = false;
        compare(f.client.cancellations, ["new-generation"]);
    }
    function test_renewalFencesOldEventsAndRepliesWithoutRetiringEffectsOrPeers() {
        const f = fixture();
        f.view.active = true;
        const old = requests(f)[0];
        reply(f, old, "old-subscription");
        f.view.call("effect", "effect.once", {});
        verify(f.view.renewBaseSubscription());
        verify(f.view.isPending("effect"));
        compare(f.client.cancellations, ["old-subscription"]);
        compare(f.client.recoveries.length, 0);
        verify(f.client.active && f.resident.ready);
        const event = {protocol: "test-api", version: 1, stream: "updates", event: "changed", data: {}, subscription_id: "old-subscription"};
        f.client.eventReceived(event, old.route);
        compare(f.view.events, 0);
        verify(f.view.renewBaseSubscription());
        compare(requests(f).length, 2, "repeated gaps coalesce during renewal");
        const fresh = requests(f)[1];
        reply(f, fresh, "fresh-subscription");
        reply(f, old, "old-subscription");
        reply(f, fresh, "fresh-subscription");
        compare(f.client.cancellations, ["old-subscription"], "duplicate replies cannot cancel the replacement");
        f.client.eventReceived(event, old.route);
        compare(f.view.events, 0);
        f.client.eventReceived(Object.assign({}, event, {subscription_id: "fresh-subscription"}), fresh.route);
        compare(f.view.events, 1);
        verify(f.view.isPending("effect"));
        compare(f.client.recoveries.length, 0);
    }
    function test_eventValidationAndGapsUseRealBackend() {
        const f = fixture();
        const event = {
            protocol: "test-api",
            version: 1,
            stream: "updates",
            event: "changed",
            data: {}
        };
        f.view.acceptSharedEvent(Object.assign({}, event, {
            protocol: "wrong-api"
        }));
        f.view.acceptSharedEvent(Object.assign({}, event, {
            version: 2
        }));
        f.view.acceptSharedEvent(Object.assign({}, event, {
            stream: ""
        }));
        f.view.acceptSharedEvent(Object.assign({}, event, {
            event: "gap"
        }));
        f.view.acceptSharedEvent(event);
        compare(f.view.events, 1);
        compare(f.view.gaps, 1);
    }
    function test_routeKindRatherThanLocalIdControlsRecovery_data() {
        return [["base-subscription", "session-subscribe", false], ["base-subscription", "different-base-id", false], ["base-subscription", "session-subscribe", true], ["subscription", "subscribe-1", false], ["subscription", "session-subscribe", false], ["call", "session-subscribe", false], ["control", "cancel-1", false]].map((row, index) => ({
                    tag: String(index),
                    kind: row[0],
                    localId: row[1],
                    ok: row[2]
                }));
    }
    function test_routeKindRatherThanLocalIdControlsRecovery(data) {
        const f = fixture();
        f.view.active = true;
        const route = {
            consumerId: f.id,
            localId: data.localId,
            kind: data.kind,
            generation: f.session.generation
        };
        const outcome = Routing.responseOutcome({
            id: data.kind === "base-subscription" ? requests(f)[0].id : f.id + "::" + data.localId,
            ok: data.ok,
            error: "subscription refused",
            route: route,
            response: {
                data: {
                    subscription: {
                        id: "sub"
                    }
                }
            }
        }, "boundary-test");
        f.client.response(outcome.id, outcome.envelope, outcome.error, outcome.route);
        const recover = data.kind === "base-subscription" && !data.ok;
        compare(f.client.recoveries.length, recover ? 1 : 0);
        if (recover) {
            const before = requests(f).length;
            Io.DaemonSessions.restoreSubscriptions("boundary-test");
            compare(requests(f).length, before + 1);
        }
    }
}
