pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io

DaemonTestCase {
    id: tests
    name: "BarPublication"
    when: windowShown
    Component {
        id: factory
        Io.BarDaemonBackend {
            daemonName: "bar-daemon"
            expectedProtocol: "bar-api"
            expectedVersion: 2
            streams: ["audio.changed", "battery.changed"]
            active: true
            property var last: ({})
            property var events: []
            onResponseReceived: function(id, envelope, error) { if (!error) last = envelope.data; }
            onEventReceived: function(event) {
                events = events.concat([event]);
                last = {snapshot: {[requestPolicy.keys[event.stream]]: event.data}};
            }
        }
    }
    function fixture() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/bar-reads.json"), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function make() { const f = createTemporaryObject(factory, tests); verify(f !== null); return f; }
    function projection(stream, revision, patch, stamp) {
        const value = fixture().changed[stream].data;
        return Object.assign({}, value, patch || {}, {_publication: Object.assign({}, value._publication, {revision: revision}, stamp || {})});
    }
    function read(f, stream, value) {
        const id = f.nextRequestId("snapshot");
        verify(f.snapshotRequest(id, [stream]));
        const call = calls.find(c => c.route.consumerId === f.sharedConsumerId && c.route.localId === id);
        verify(call !== undefined);
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id,
            {protocol: "bar-api", version: 2, ok: true, data: {snapshot: {[f.requestPolicy.keys[stream]]: value}}}, "", call.route);
    }
    function push(f, stream, value, kind) {
        const envelope = fixture().changed[stream];
        envelope.data = value;
        envelope.event = kind || "changed";
        const route = {consumerId: f.sharedConsumerId, localId: "session-subscribe", kind: "base-subscription",
            generation: Io.DaemonSessions.sessions["bar-daemon"].generation};
        // Use the actual base request's transport generation, not a domain cursor.
        const session = Io.DaemonSessions.sessions["bar-daemon"];
        const consumer = session.consumers[f.sharedConsumerId];
        const sub = session.client.subscriptions.find(s => s.id === consumer.baseSubscriptionRequestId);
        emitBaseEvent("bar-daemon", sub ? sub.route : route, envelope);
    }
    function test_readCanPrecedeOlderInitialEventAndDuplicateBodiesNeverPublish() {
        const f = make();
        read(f, "audio.changed", projection("audio.changed", 4, {volume_percent: 40}));
        push(f, "audio.changed", projection("audio.changed", 1, {volume_percent: 10}), "subscribed");
        push(f, "audio.changed", projection("audio.changed", 3, {volume_percent: 30}));
        push(f, "audio.changed", projection("audio.changed", 4, {volume_percent: 99}));
        compare(f.events.length, 0);
        compare(f.last.snapshot.audio.volume_percent, 40);
        push(f, "audio.changed", projection("audio.changed", 5, {volume_percent: 50}));
        compare(f.last.snapshot.audio.volume_percent, 50);
        read(f, "audio.changed", projection("audio.changed", 2, {volume_percent: 20}));
        compare(f.last.snapshot.audio.volume_percent, 50, "a stale read can confirm only the already accepted value");
    }
    function test_malformedProjectionDoesNotConsumeRevisionAndOldProducerFailsClosed() {
        const f = make();
        read(f, "audio.changed", projection("audio.changed", 4, {volume_percent: 40}));
        const bad = projection("audio.changed", 5, {available: "yes"});
        read(f, "audio.changed", bad);
        compare(f.requestPolicy.cursor("audio.changed").revision, 4);
        compare(f.events.slice(-1)[0].data.available, false, "untrusted projections disable live controls without advancing the cursor");
        for (const revision of [0, 1.5, 9007199254740992]) {
            read(f, "audio.changed", projection("audio.changed", revision));
            compare(f.requestPolicy.cursor("audio.changed").revision, 4);
        }
        delete bad._publication;
        read(f, "audio.changed", bad);
        verify(f.requestPolicy.error.includes("matching daemon required"));
        read(f, "audio.changed", projection("audio.changed", 5, {volume_percent: 50}));
        compare(f.last.snapshot.audio.volume_percent, 50);
        compare(f.requestPolicy.error, "");
    }
    function test_rolloverLineageRejectsRetiredAndUnrelatedEpochsWithoutReadLoop() {
        const f = make();
        const old = projection("audio.changed", 9007199254740991);
        read(f, "audio.changed", old);
        push(f, "audio.changed", projection("audio.changed", 3, {volume_percent: 60}, {epoch: "new-epoch", previous_epoch: old._publication.epoch}));
        compare(f.last.snapshot.audio.volume_percent, 60);
        push(f, "audio.changed", old);
        compare(f.last.snapshot.audio.volume_percent, 60);
        read(f, "audio.changed", projection("audio.changed", 1, {}, {epoch: "unrelated"}));
        verify(f.requestPolicy.error.includes("reconnect required"));
        const count = calls.length;
        wait(0);
        compare(calls.length, count);
    }
    function test_quietLossRefreshAndOrderedDiscontinuityDoNotInventEdgesOrRetirePeers() {
        const f = make();
        const peer = make();
        read(f, "battery.changed", projection("battery.changed", 2, {percentage: 40}));
        push(peer, "audio.changed", projection("audio.changed", 2));
        const session = Io.DaemonSessions.sessions["bar-daemon"];
        const peerSubscription = session.consumers[peer.sharedConsumerId].baseSubscriptionId;
        // Revision 3 was lost. Revision 4 repairs current state, not an OSD edge.
        push(f, "battery.changed", projection("battery.changed", 4, {percentage: 60}));
        compare(f.events.slice(-1)[0].event, "subscribed");
        compare(f.last.snapshot.battery.percentage, 60);
        // A final replacement is lost silently: explicit read converges.
        read(f, "battery.changed", projection("battery.changed", 5, {percentage: 70}));
        compare(f.last.snapshot.battery.percentage, 70);
        verify(f.renewBaseSubscription());
        push(f, "battery.changed", projection("battery.changed", 6, {percentage: 80}), "subscribed");
        compare(f.last.snapshot.battery.percentage, 80);
        compare(session.consumers[peer.sharedConsumerId].baseSubscriptionId, peerSubscription);
        verify(calls.every(c => c.method === "bar.snapshot"), "recovery never launches an effect");
    }
    function test_effectReceiptIsNotStateAndOlderNestedCompletionCannotRollBack() {
        const f = make();
        read(f, "battery.changed", projection("battery.changed", 4, {percentage: 80}));
        f.requestPolicy.sending("battery-result", "battery.operation.start", {});
        const response = f.requestPolicy.received("battery-result", {protocol: "bar-api", version: 2, ok: true,
            data: {battery: {percentage: 10}, snapshot: {battery: projection("battery.changed", 2, {percentage: 20})}, saved: true}}, "");
        compare(response.data.observations.battery.percentage, 10);
        verify(response.data.saved);
        compare(response.data.battery, undefined);
        compare(response.data.snapshot.battery.percentage, 80);
    }
}
