pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../bluetooth" as Bt

DaemonTestCase {
    id: tests
    name: "BluetoothStreamRecovery"
    when: windowShown
    Component { id: factory; Bt.BluetoothController {} }
    function fixture() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../../contracts/bt-api-ui-contract.fixture.json"), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function setup() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        const backend = findChild(controller, "bluetoothBackend");
        const session = Io.DaemonSessions.sessions["bt-daemon"];
        const consumer = session.consumers[backend.sharedConsumerId];
        const subscription = session.client.subscriptions.find(r => r.id === consumer.baseSubscriptionRequestId);
        verify(subscription !== undefined);
        const data = fixture();
        session.client.response(subscription.id, {ok: true, data: {subscription: {id: "ordering-subscription"}}}, "", subscription.route);
        wait(0);
        const read = calls.find(call => call.route.consumerId === backend.sharedConsumerId && call.method === "bluetooth.snapshot");
        verify(read !== undefined);
        calls = [];
        return {c: controller, b: backend, session: session, subscription: subscription,
            read: read, data: data, records: data.snapshot_ordering};
    }
    function send(f, event) { f.session.client.eventReceived(event, f.subscription.route); }
    function reply(f, response) { f.session.client.response(f.read.id, response, "", f.read.route); }
    function test_rpcEventRaceIncludesLoadingUnavailableDuplicatesAndOldEpochs() {
        const f = setup();
        send(f, f.records.baseline);
        send(f, f.records.changed);
        verify(f.c.radio.powered);
        reply(f, f.records.old_read);
        reply(f, f.records.loading_read);
        send(f, f.records.loading);
        send(f, f.records.baseline);
        verify(f.c.radio.powered);
        verify(!f.c.backendLoading);
        const oldEpoch = JSON.parse(JSON.stringify(f.records.unavailable));
        oldEpoch.data.state.epoch = "retired-epoch";
        send(f, oldEpoch);
        verify(f.c.backendAvailable);
        send(f, f.records.unavailable);
        verify(!f.c.backendAvailable);
        reply(f, f.records.latest_read);
        send(f, f.records.changed);
        verify(!f.c.backendAvailable, "late available snapshots cannot undo a newer outage");
    }
    function test_finalReplacementLossIsRepairedByReadWithoutEffectReplay() {
        const f = setup();
        send(f, f.records.baseline);
        verify(!f.c.radio.powered);
        // Drop the changed event completely; its authoritative read still repairs state.
        reply(f, f.records.latest_read);
        verify(f.c.radio.powered);
        compare(findChild(f.b, "bluetoothRadioCursor").revision, 3);
        verify(calls.every(call => call.method.endsWith(".snapshot")), "only read recovery is allowed");
    }
    function test_malformedDataAndMissingMetadataDoNotConsumeValidState() {
        const f = setup();
        send(f, f.records.baseline);
        const broken = JSON.parse(JSON.stringify(f.records.changed));
        broken.data.snapshot.devices = {};
        send(f, broken);
        compare(findChild(f.b, "bluetoothRadioCursor").revision, 2);
        delete broken.data.snapshot;
        broken.data = JSON.parse(JSON.stringify(f.records.changed.data));
        delete broken.data.state;
        send(f, broken);
        compare(findChild(f.b, "bluetoothRadioCursor").revision, 2);
        send(f, f.records.changed);
        verify(f.c.radio.powered);
        compare(findChild(f.b, "bluetoothRadioCursor").revision, 3);
    }
    function test_audioIsIndependentAndLateReadCannotUndoUnavailable() {
        const f = setup();
        send(f, f.records.changed);
        send(f, f.records.audio_event);
        const read = JSON.parse(JSON.stringify(f.data.audio_snapshot));
        read.data.state.revision = 2;
        f.b.acceptSharedResponse("audio-snapshot", read, "");
        verify(f.c.audioDevices.length > 0);
        const unavailable = JSON.parse(JSON.stringify(f.records.audio_event));
        unavailable.event = "unavailable";
        unavailable.data = {state: {epoch: "fixture-audio", revision: 3}};
        unavailable.error = {code: "audio-unavailable", message: "Unavailable"};
        send(f, unavailable);
        f.b.acceptSharedResponse("audio-snapshot", read, "");
        compare(f.c.audioDevices.length, 0);
        compare(f.c.audioStatus, "Unavailable");
        verify(f.c.radio.powered, "audio recovery never resets the radio publisher");
    }
    function test_mutationObservationsCannotReplaceLiveStateOrClearPromptDrafts() {
        const f = setup();
        send(f, f.records.changed);
        f.c.handlePairingEvent({event: "requested", data: {request_id: "prompt", device_key: "buds", kind: "pin-code", response_required: true}});
        f.c.pairingInput = "fixture-draft";
        f.b.pending = ({});
        calls = [];
        f.b.acceptSharedResponse("management-update", f.data.snapshot, "");
        f.c.handleOperationEvent({request_id: "operation", device_key: "buds", state: "completed", operation: "connect", snapshot: f.records.old_read.data.snapshot});
        f.c.handleScanEvent({request_id: "scan", state: "completed", snapshot: f.records.old_read.data.snapshot});
        verify(f.c.radio.powered);
        // Operation completion may close its own device prompt; use a distinct
        // identity for unrelated prompt retention in the state-only path below.
        f.c.handlePairingEvent({event: "requested", data: {request_id: "other-prompt", device_key: "other", kind: "pin-code", response_required: true}});
        f.c.pairingInput = "retained-draft";
        reply(f, f.records.old_read);
        verify(f.c.radio.powered);
        compare(f.c.pairingInput, "retained-draft");
        compare(f.c.pairingPrompt.request_id, "other-prompt");
        verify(calls.every(call => call.method.endsWith(".snapshot")));
        compare(calls.filter(call => call.method === "bluetooth.snapshot").length, 1, "coalesce recovery reads, never effects");
    }
    function test_reconnectFencesRetiredGenerationAndAcceptsFreshEpoch() {
        const f = setup();
        send(f, f.records.changed);
        f.session.client.transportFailed("fixture-disconnect");
        const fresh = JSON.parse(JSON.stringify(f.records.old_read));
        fresh.data.state.epoch = "fresh-epoch";
        reply(f, f.records.latest_read); // old route generation
        compare(findChild(f.b, "bluetoothRadioCursor").epoch, "");
        f.b.acceptSharedResponse("snapshot", fresh, "");
        verify(!f.c.radio.powered);
        compare(findChild(f.b, "bluetoothRadioCursor").epoch, "fresh-epoch");
        send(f, f.records.changed);
        verify(!f.c.radio.powered);
    }
}
