pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../launcher" as Apps

DaemonTestCase {
    id: tests
    name: "ApplicationStreamRecovery"
    when: windowShown
    Component { id: factory; Apps.ApplicationController { uiActive: true; scheduledRefreshDelay: 60000 } }
    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/" + name + ".json"), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function setup() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        const session = Io.DaemonSessions.sessions["app-daemon"];
        const consumer = Object.values(session.consumers).find(c => c.backend.controller === controller);
        verify(consumer !== undefined);
        const sub = session.client.subscriptions.find(s => s.id === consumer.baseSubscriptionRequestId);
        verify(sub !== undefined);
        emitBaseEvent("app-daemon", sub.route, fixture("app-events")["applications.changed.subscribed"]);
        calls = [];
        return {c: controller, b: consumer.backend, session: session, sub: sub};
    }
    function query(f) {
        calls = [];
        f.c.refresh(false);
        tryVerify(() => calls.some(c => c.method === "applications.query"));
        return calls.find(c => c.method === "applications.query");
    }
    function reply(f, request, revision) {
        const envelope = fixture("app-replies")["applications.query"];
        envelope.data.applications.revision = revision;
        f.session.client.response(request.id, envelope, "", request.route);
    }
    function test_invalidationFencesReadEvenBeforeDebouncedReplacementDispatch() {
        const f = setup();
        const old = query(f);
        emitBaseEvent("app-daemon", f.sub.route, fixture("app-events")["windows.changed"]);
        reply(f, old, 10);
        compare(f.c.catalogRevision, -1, "a late read cannot briefly republish an invalidated catalog");
        const fresh = query(f);
        reply(f, fresh, 11);
        compare(f.c.catalogRevision, 11);
        reply(f, old, 10);
        compare(f.c.catalogRevision, 11);
    }
    function test_contentTokensAreNotOrderingAndExplicitReadRepairsQuietLoss() {
        const f = setup();
        const first = query(f);
        reply(f, first, 1000);
        compare(f.c.catalogRevision, 1000);
        // No invalidation arrives at all. Explicit refresh observes current
        // state, including a numerically lower content-derived identity.
        const refreshed = query(f);
        reply(f, refreshed, 7);
        compare(f.c.catalogRevision, 7);
        verify(calls.every(c => c.method === "applications.query"));
    }
    function test_staleReadFailureDoesNotReplaceCurrentDiagnostics() {
        const f = setup();
        const old = query(f);
        emitBaseEvent("app-daemon", f.sub.route, fixture("app-events")["applications.changed"]);
        f.c.catalogError = "current diagnostic";
        f.session.client.response(old.id, null, "late read failure", old.route);
        compare(f.c.catalogError, "current diagnostic");
    }
}
