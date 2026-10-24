pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Wifi as Wifi

DaemonTestCase {
    id: tests
    name: "WifiStreamRecovery"
    when: windowShown
    Component { id: factory; Wifi.WifiController { uiActive: true; prompt: Wifi.WifiPromptController {} } }
    property var loaded: null
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("../../contracts/nm-api-ui-contract.fixture.json"), false);
            request.send();
            loaded = JSON.parse(request.responseText).data.fixture.network_stream;
        }
        return JSON.parse(JSON.stringify(loaded));
    }
    function setup() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        const session = Io.DaemonSessions.sessions["nm-daemon"];
        const consumer = session.consumers[controller.backend.networkEvents.sharedConsumerId];
        const request = session.client.subscriptions.find(r => r.id === consumer.baseSubscriptionRequestId);
        verify(request !== undefined);
        const data = fixture();
        // Rebind opaque fixture identities, never the producer's domain data.
        for (const event of Object.values(data)) {
            event.subscription_id += ":" + controller.backend.networkEvents.sharedConsumerId;
            event.data.epoch += ":" + controller.backend.networkEvents.sharedConsumerId;
        }
        session.client.response(request.id, {ok: true, data: {subscription: {id: data.initial.subscription_id}}}, "", request.route);
        calls = [];
        return {c: controller, session: session, consumer: consumer, request: request, data: data};
    }
    function send(f, event, request) { f.session.client.eventReceived(event, (request || f.request).route); }
    function keys(c) { return c.visibleNetworks.map(row => row.key); }
    function test_gapRenewsOnlySubscriptionAndPreservesPromptAndOperation() {
        const f = setup();
        const c = f.c;
        send(f, f.data.initial);
        const old = keys(c);
        c.connection.requestId = "connect-owned";
        c.prompt.openPrompt("daemon-secret", "Credentials", "", true, null);
        c.prompt.secretRequestId = "secret-owned";
        c.prompt.text = "unsubmitted fixture draft";
        const mixed = f.session.consumers[c.backend.sharedConsumerId];
        const mixedRequest = mixed.baseSubscriptionRequestId;
        const count = f.session.client.subscriptions.length;
        const cancellations = f.session.client.cancellations.length;
        // Drop the record adding B, then receive the record removing A. Applying
        // it without recovery would leave an empty collection instead of B.
        send(f, f.data.after_gap);
        compare(keys(c), old);
        verify(c.backend.networkCursor.recovering);
        compare(f.session.client.subscriptions.length, count + 1);
        compare(mixed.baseSubscriptionRequestId, mixedRequest, "SecretAgent/status observers are not renewed");
        compare(f.session.client.subscriptions.slice(-1)[0].streams, ["wifi.networks"]);
        compare(f.session.client.cancellations.slice(cancellations), [f.data.initial.subscription_id]);
        compare(c.connection.requestId, "connect-owned");
        verify(c.prompt.open);
        compare(c.prompt.text, "unsubmitted fixture draft");
        compare(calls.length, 0, "recovery does not replay a connect/scan or request a racing cache read");
        send(f, f.data.lost);
        send(f, f.data.initial);
        compare(keys(c), old, "retired subscription traffic is fenced before projection");
        const current = f.session.client.subscriptions.find(r => r.id === f.consumer.baseSubscriptionRequestId);
        f.session.client.response(current.id, {ok: true, data: {subscription: {id: f.data.replacement.subscription_id}}}, "", current.route);
        send(f, f.data.replacement, current);
        compare(keys(c), f.data.replacement.data.added.map(row => row.key));
        verify(!c.backend.networkCursor.recovering);
        send(f, f.data.initial);
        compare(keys(c), f.data.replacement.data.added.map(row => row.key));
        compare(c.connection.requestId, "connect-owned");
        compare(c.prompt.text, "unsubmitted fixture draft");
        compare(calls.length, 0);
    }
    function test_liveBaselineFencesLateReadAndScanCollectionsAndDuplicateEvents() {
        const f = setup();
        const c = f.c;
        send(f, f.data.initial);
        send(f, f.data.lost);
        const expected = keys(c);
        compare(expected.length, 2);
        send(f, f.data.initial);
        compare(keys(c), expected);
        c.backend.handleNetworks({protocol: "nm-api", version: 2, ok: true, data: {networks: [], snapshot: {}}});
        c.scan.applyEvent({event: "snapshot", data: {networks: [], networks_found: 0}});
        compare(keys(c), expected, "unversioned replies cannot overwrite the delta base");
        send(f, f.data.after_gap);
        compare(keys(c), f.data.replacement.data.added.map(row => row.key));
        compare(calls.length, 0);
    }
    function test_scanCompletionRefreshesBaselineWithoutStartingAnotherEffect() {
        const f = setup();
        send(f, f.data.initial);
        f.c.scan.requestId = "scan-owned";
        const count = f.session.client.subscriptions.length;
        // Neither lost nor after_gap arrives: completion must still let the
        // user obtain an authoritative fresh collection without another scan.
        f.c.scan.handleStream({request_id: "scan-owned", event: "complete", data: {networks_found: 1}});
        verify(f.c.backend.networkCursor.recovering);
        compare(f.session.client.subscriptions.length, count + 1);
        compare(f.c.scan.requestId, "");
        compare(calls.length, 0);
    }
    function test_malformedRowsDoNotAdvanceCursorAndOtherConsumersStayLive() {
        const f = setup();
        const peer = setup();
        send(f, f.data.initial);
        send(peer, peer.data.initial);
        const bad = f.data.lost;
        bad.data.added = [{key: 9}];
        send(f, bad);
        compare(f.c.backend.networkCursor.revision, 1);
        verify(f.c.backend.networkCursor.recovering);
        verify(peer.c.backend.ready);
        send(peer, peer.data.lost);
        compare(keys(peer.c).length, 2);
        compare(peer.c.backend.networkCursor.revision, 2);
        compare(calls.length, 0);
    }
}
