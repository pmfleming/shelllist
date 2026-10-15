pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Bar as Bar

DaemonTestCase {
    id: tests
    name: "BarDomainRecovery"
    when: windowShown
    Component { id: factory; Bar.BarController { surfaceRegistry: null } }

    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function make() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        return controller;
    }
    function reads(backend) { return calls.filter(call => call.route.consumerId === backend.sharedConsumerId && call.method === "bar.snapshot"); }
    function reply(call, snapshot) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id,
            {protocol: "bar-api", version: 2, ok: true, data: {snapshot: snapshot}}, "", call.route);
    }
    function event(call, stream, kind, data) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/bar-reads.json"), false);
        request.send();
        const fixtures = JSON.parse(request.responseText);
        const group = fixtures[kind === "gap" ? "lagged" : kind];
        // Positive events start with the production serializer, not a partial fake.
        const envelope = group ? group[stream] : {protocol: "bar-api", version: 2, stream: stream, event: kind, data: {}};
        // Gap payloads are used verbatim; only state telemetry is varied.
        if (kind !== "gap")
            envelope.data = Object.assign(envelope.data, data);
        const route = Object.assign({}, call.route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(envelope, route);
    }
    function test_gapStormIsSingleFlightAndDomainLocal() {
        const controller = make();
        const backend = controller.backend;
        const initial = reads(backend)[0];
        reply(initial, {audio: {available: true, volume_percent: 5}, battery: {available: true, percentage: 80}});
        for (let i = 0; i < 100; ++i)
            event(initial, "audio.changed", "gap", {});
        compare(reads(backend).length, 2);
        compare(reads(backend)[1].params.streams, ["audio.changed"]);
        verify(!backend.snapshot(), "Manual refresh cannot overlap recovery");
        const first = reads(backend)[1];
        reply(first, {audio: {available: true, volume_percent: 10}, battery: {available: false}});
        // Gaps arriving during the read invalidate it and schedule just one follow-up.
        tryCompare(backend.requestPolicy, "snapshotRequests", 3);
        compare(controller.audio.volume_percent, 5);
        compare(controller.battery.percentage, 80);
        reply(reads(backend)[2], {audio: {available: true, volume_percent: 50}, battery: {available: false}});
        compare(controller.audio.volume_percent, 50);
        compare(controller.battery.percentage, 80, "Old daemon full replies are projected locally");
        wait(0);
        compare(reads(backend).length, 3);
        compare(Object.keys(backend.requestPolicy.requests).length, 0);
        console.info("SHELLLIST_RELIABILITY " + JSON.stringify({scenario: "qml-production-gap-burst", gaps: 100, initialReads: 1, recoveryReads: reads(backend).length - 1, pendingAfterRecovery: Object.keys(backend.requestPolicy.requests).length}));
    }
    function test_newerPushFencesLateStartupAndRecoveryReplies() {
        const controller = make();
        const backend = controller.backend;
        const initial = reads(backend)[0];
        event(initial, "audio.changed", "changed", {available: true, volume_percent: 70});
        event(initial, "battery.changed", "unknown-event", {available: false});
        reply(initial, {audio: {available: true, volume_percent: 10}, battery: {available: true, percentage: 80}});
        compare(controller.audio.volume_percent, 70);
        compare(controller.battery.percentage, 80);
        event(initial, "audio.changed", "gap", {});
        const recovery = reads(backend)[1];
        event(initial, "audio.changed", "changed", {available: true, volume_percent: 90});
        reply(recovery, {audio: {available: true, volume_percent: 20}});
        compare(controller.audio.volume_percent, 90);
        wait(0);
        compare(reads(backend).length, 2, "A complete newer push satisfies recovery");
    }
    function test_failedRecoveryReleasesFlightWithoutLooping_data() {
        return [{tag: "timeout", malformed: false}];
    }
    function test_failedRecoveryReleasesFlightWithoutLooping(data) {
        const controller = make();
        const backend = controller.backend;
        const initial = reads(backend)[0];
        reply(initial, {});
        event(initial, "audio.changed", "gap", {});
        const recovery = reads(backend)[1];
        if (data.malformed)
            reply(recovery, {});
        else
            Io.DaemonSessions.sessions["bar-daemon"].client.response(recovery.id, null, "injected read timeout", recovery.route);
        compare(Object.keys(backend.requestPolicy.requests).length, 0);
        compare(backend.requestPolicy.snapshotFailures, 1);
        wait(0);
        compare(reads(backend).length, 2);
        event(initial, "audio.changed", "gap", {});
        compare(reads(backend).length, 3);
    }
    function test_processLossInvalidatesStateAndOldGenerationReply() {
        const controller = make();
        const backend = controller.backend;
        const initial = reads(backend)[0];
        reply(initial, {audio: {available: true, volume_percent: 30}});
        event(initial, "audio.changed", "gap", {});
        const recovery = reads(backend)[1];
        const client = Io.DaemonSessions.sessions["bar-daemon"].client;
        clientReady = false;
        client.transportFailed("injected process exit");
        compare(controller.audio.available, false);
        compare(Object.keys(backend.requestPolicy.requests).length, 0);
        clientReady = true;
        const current = reads(backend)[reads(backend).length - 1];
        reply(current, {audio: {available: true, volume_percent: 80}});
        reply(recovery, {audio: {available: true, volume_percent: 10}});
        compare(controller.audio.volume_percent, 80);
        verify(backend.requestPolicy.generation > 0);
    }
}
