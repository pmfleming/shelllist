pragma ComponentBehavior: Bound
import QtQuick
import "../../bluetooth" as Bt
import "../../bluetooth/BtApi.js" as BtApi
import "../../bluetooth/BtProtocol.generated.js" as Protocol

DaemonTestCase {
    id: tests
    name: "BluetoothOperations"
    when: windowShown
    Component { id: factory; Bt.BluetoothController {} }
    function load(path) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(path), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function test_unacknowledgedAggregateDoesNotGrantPeerCancellation() {
        const owner = setup();
        const peer = setup();
        verify(owner.b.ready && peer.b.ready);
        verify(owner.b.sharedConsumerId !== peer.b.sharedConsumerId);
        receipt(owner);
        snapshot(peer, [owner.data.queued], []);
        compare(peer.b.cancelOperation(owner.data.queued.request_id), false,
            "A shared-owner aggregate is not this consumer's accepted-work authority");
    }
    function test_recoveredTerminalRetainsUnrelatedSameDevicePrompt() {
        const f = setup();
        receipt(f);
        f.c.handlePairingEvent({event: "requested", data: {request_id: "later-independent-prompt",
            device_key: f.data.queued.device_key, kind: "pin-code", response_required: true}});
        f.c.pairingInput = "coordinator-synthetic-draft";
        compare(f.c.pairingPrompt.request_id, "later-independent-prompt");
        f.r.poll();
        status(f, f.data.completed);
        compare(f.c.pairingInput, "coordinator-synthetic-draft",
            "An operation outcome has no ordering/authority over a separate prompt on the same device");
        compare(f.c.pairingPrompt.request_id, "later-independent-prompt");
    }
    function test_producerFixtureAndGeneratedBindingsStayInParity() {
        const contract = load("../../contracts/bt-api-ui-contract.fixture.json");
        const operations = load("fixtures/bt-operations.json");
        compare(contract.operation_ordering, operations);
        compare(contract.operation_event.data, operations.completed);
        compare(operations.status.data.operation_status, operations.completed);
        for (const method of contract.registry.methods)
            compare(Protocol.methods[method.name], method.name);
        for (const stream of contract.registry.streams)
            compare(Protocol.streams[stream.name], stream.name);
        const statusMethod = contract.registry.methods.find(method => method.name === BtApi.methods.operationStatus);
        verify(statusMethod !== undefined);
        compare(statusMethod.response_key, "operation_status", "status reads are not admission receipts");
        compare(statusMethod.cancellable, false);
        for (const name of ["queued", "started", "progress", "completed", "failed", "cancelled"]) {
            verify(BtApi.validOperation(operations[name]), name);
            verify(!("owner" in operations[name]), "private owner identities never cross the wire");
        }
    }
    function setup() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        controller.searchScope = "mine";
        controller.applySnapshot(load("../../contracts/bt-api-ui-contract.fixture.json").snapshot.data.snapshot);
        wait(0);
        const backend = findChild(controller, "bluetoothBackend");
        const recovery = findChild(backend, "bluetoothOperationRecovery");
        verify(recovery !== null);
        backend.pending = ({});
        calls = [];
        return {c: controller, b: backend, r: recovery, data: load("fixtures/bt-operations.json")};
    }
    function receipt(f, operation) {
        f.b.acceptSharedResponse("device-connect", {protocol: "bt-api", version: 2, ok: true,
            data: {operation: operation || f.data.queued}}, "");
    }
    function event(f, operation) {
        f.b.handleEvent({protocol: "bt-api", version: 2, stream: "bluetooth.operation",
            event: operation.event, data: operation});
    }
    function status(f, operation, error) {
        const id = f.r.statusRequestId;
        verify(id.length > 0);
        f.b.acceptSharedResponse(id, error ? {protocol: "bt-api", version: 2, ok: false,
            error: {code: "request-not-found", message: error}} : {protocol: "bt-api", version: 2, ok: true,
            data: {operation_status: operation}}, "");
    }
    function snapshot(f, active, recent) {
        f.b.restoreRequestState({operations: {active: active, recent: recent}, scans: {active: []}, pairing: {active: []}});
    }
    function test_aggregateReconcilesOnlyAcknowledgedLocalIds() {
        const f = setup();
        receipt(f);
        const peer = Object.assign({}, f.data.progress, {request_id: "peer-operation", device_key: "peer-device"});
        snapshot(f, [f.data.progress, peer], []);
        compare(Object.keys(f.b.operations), [f.data.queued.request_id]);
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 3);
        verify(!f.c.deviceBusy(peer.device_key));
        verify(!f.b.cancelOperation(peer.request_id));
        verify(f.b.cancelOperation(f.data.queued.request_id), "local acknowledgement retains cancellation authority");
        verify(f.c.deviceBusy(f.data.queued.device_key), "cancellation acknowledgement is not completion");
        snapshot(f, [], [f.data.completed, Object.assign({}, f.data.completed, {request_id: peer.request_id})]);
        verify(!f.c.deviceBusy(f.data.queued.device_key));
        verify(f.b.finishedOperations[f.data.queued.request_id]);
        verify(!f.b.finishedOperations[peer.request_id], "aggregate peer history is not a local retirement fence");
        verify(!f.b.cancelOperation(f.data.queued.request_id));
        snapshot(f, [f.data.progress, peer], []);
        verify(!f.c.deviceBusy(f.data.queued.device_key), "terminal fence cannot reopen local work");
        f.r.poll();
        verify(!calls.some(call => call.method === BtApi.methods.operationStatus));
    }
    function test_aggregateBeforeReceiptCannotAdoptOrRetireIt_data() {
        return [{tag: "active", active: true}, {tag: "recent", active: false}];
    }
    function test_aggregateBeforeReceiptCannotAdoptOrRetireIt(data) {
        const f = setup();
        snapshot(f, data.active ? [f.data.progress] : [], data.active ? [] : [f.data.completed]);
        compare(Object.keys(f.b.operations).length, 0);
        compare(Object.keys(f.b.finishedOperations).length, 0);
        verify(!f.b.cancelOperation(f.data.queued.request_id));
        receipt(f);
        verify(f.c.deviceBusy(f.data.queued.device_key));
        f.r.poll();
        status(f, f.data.completed);
        verify(!f.c.deviceBusy(f.data.queued.device_key));
    }
    function test_terminalDoesNotOwnSameDevicePrompts_data() {
        const rows = [];
        for (const source of ["live", "status", "aggregate"])
            for (const state of ["completed", "failed", "cancelled"])
                rows.push({tag: source + "-" + state, source: source, state: state});
        return rows;
    }
    function test_terminalDoesNotOwnSameDevicePrompts(data) {
        const f = setup();
        receipt(f, Object.assign({}, f.data.queued, {operation: "pair"}));
        for (const id of ["first-prompt", "second-prompt"])
            f.c.handlePairingEvent({event: "requested", data: {request_id: id,
                device_key: f.data.queued.device_key, kind: "pin-code", response_required: true}});
        f.c.pairingInput = "unsaved-first-draft";
        verify(f.c.respondPairing(true));
        compare(f.c.respondingPairingId, "first-prompt");
        const terminal = Object.assign({}, f.data[data.state], {operation: "pair"});
        if (data.source === "live")
            event(f, terminal);
        else if (data.source === "aggregate")
            f.r.restore({active: [], recent: [terminal]});
        else {
            f.r.poll();
            status(f, terminal);
        }
        verify(!f.c.deviceBusy(f.data.queued.device_key));
        compare(f.c.pairingPrompt.request_id, "first-prompt");
        compare(f.c.pairingInput, "unsaved-first-draft");
        compare(f.c.respondingPairingId, "first-prompt", "operation completion cannot retire a prompt response window");
        // Prompt-specific lifecycle closes only its ID, even on the same device.
        f.c.handlePairingEvent({event: "cancelled", data: {request_id: "first-prompt"}});
        compare(f.c.pairingPrompt.request_id, "second-prompt");
        f.c.pairingInput = "unsaved-second-draft";
        f.b.acceptSharedResponse("pairing-response", {protocol: "bt-api", version: 2, ok: true, data: {}}, "");
        compare(f.c.pairingPrompt.request_id, "second-prompt", "late acknowledgement targets the captured first ID");
        compare(f.c.pairingInput, "unsaved-second-draft");
        verify(f.c.respondPairing(true));
        f.b.acceptSharedResponse("pairing-response", {protocol: "bt-api", version: 2, ok: true, data: {}}, "");
        verify(!f.c.pairingPromptOpen, "acknowledgement still closes its own prompt");
        compare(f.c.pairingInput, "");
    }
    function test_quietTerminalLossIsRepairedByActualTimerWithoutEffectReplay() {
        const f = setup();
        receipt(f);
        verify(f.c.deviceBusy("device-opaque"));
        f.c.activeScan = {request_id: "retained-scan", state: "running"};
        f.c.handlePairingEvent({event: "requested", data: {request_id: "private-prompt", device_key: "other",
            kind: "pin-code", response_required: true}});
        f.c.pairingInput = "private-fixture-draft";
        tryVerify(() => calls.some(call => call.method === "bluetooth.operation.status"), 2000);
        const read = calls.find(call => call.method === "bluetooth.operation.status");
        compare(read.params, {request_id: f.data.queued.request_id});
        verify(!f.c.globalRequestInFlight, "background status reads must not block unrelated mutations");
        status(f, f.data.completed);
        verify(!f.c.deviceBusy("device-opaque"));
        compare(f.c.activeScan.request_id, "retained-scan");
        compare(f.c.pairingInput, "private-fixture-draft");
        compare(f.c.pairingPrompt.request_id, "private-prompt");
        verify(calls.every(call => call.method.endsWith(".snapshot") || call.method === "bluetooth.operation.status"));
        event(f, f.data.started);
        receipt(f); // A late queued receipt cannot consume its terminal fence.
        snapshot(f, [f.data.progress], []);
        verify(!f.c.deviceBusy("device-opaque"));
    }
    function test_operationGapUsesOnlyOwnedStatusAndRetainsPromptAndScan() {
        const f = setup();
        receipt(f);
        f.c.activeScan = {request_id: "scan", state: "running"};
        f.c.handlePairingEvent({event: "requested", data: {request_id: "private-prompt", device_key: "other",
            kind: "pin-code", response_required: true}});
        f.c.pairingInput = "retained-private-draft";
        f.b.acceptSharedEvent({protocol: "bt-api", version: 2, stream: "bluetooth.operation", event: "gap",
            data: {reason: "subscriber-lag", dropped_events: "2"}});
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.operation.status");
        compare(f.c.pairingInput, "retained-private-draft");
        compare(f.c.activeScan.request_id, "scan");
        verify(f.c.deviceBusy("device-opaque"));
        status(f, f.data.progress);
        compare(f.c.pairingInput, "retained-private-draft");
    }
    function test_statusEventSnapshotRacesRejectOlderAndDuplicateRevisions() {
        const f = setup();
        receipt(f);
        f.r.poll();
        const currentRead = f.r.statusRequestId;
        f.b.acceptSharedResponse("operation-status-retired", f.data.status, "");
        compare(f.r.statusRequestId, currentRead, "an unowned completion cannot retire the current status read");
        verify(f.c.deviceBusy("device-opaque"), "an unowned status cannot supply terminal authority");
        event(f, f.data.progress);
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 3);
        status(f, f.data.started);
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 3);
        receipt(f);
        snapshot(f, [f.data.started], []);
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 3);
        f.r.poll();
        event(f, f.data.failed);
        compare(f.c.operationErrorForDevice("device-opaque").message, "fixture failure");
        status(f, f.data.progress);
        event(f, f.data.failed);
        event(f, f.data.progress);
        snapshot(f, [f.data.queued], []);
        verify(!f.c.deviceBusy("device-opaque"));
        compare(f.c.operationErrorForDevice("device-opaque").message, "fixture failure");
    }
    function test_recoveredPairFailureCannotTriggerSnapshotDrivenOrDirectRescan() {
        const f = setup();
        const queued = Object.assign({}, f.data.queued, {operation: "pair"});
        receipt(f, queued);
        f.c.uiActive = true;
        f.c.searchScope = "all";
        f.c.scanRequested = false;
        f.r.poll();
        const failed = Object.assign({}, f.data.failed, {operation: "pair",
            error: {code: "device-unavailable", message: "Fixture unavailable"}});
        status(f, failed);
        verify(!f.c.deviceBusy("device-opaque"));
        compare(calls.length, 1, "outcome recovery cannot start a scan indirectly through a radio read");
        compare(calls[0].method, "bluetooth.operation.status");
        verify(!f.c.scanning);
    }
    function test_preAcceptanceAndForeignEventsDoNotAcquireLocalAuthority() {
        const f = setup();
        event(f, f.data.completed); // Terminal delivery races the queued receipt.
        verify(!f.c.deviceBusy("device-opaque"));
        const foreign = Object.assign({}, f.data.progress, {request_id: "foreign"});
        event(f, foreign);
        compare(Object.keys(f.b.operations).length, 0);
        receipt(f);
        f.r.poll();
        status(f, f.data.completed);
        verify(!f.c.deviceBusy("device-opaque"));
        verify(!f.b.operations.foreign);
    }
    function test_absentAggregateRowsAndRadioOutagePreserveAcceptedWork() {
        const f = setup();
        receipt(f);
        snapshot(f, [], []);
        verify(f.c.deviceBusy("device-opaque"), "absence is not an outcome");
        f.c.invalidateBluetooth("fixture outage");
        verify(f.c.deviceBusy("device-opaque"), "watch outage is not operation cancellation");
        f.r.poll();
        status(f, f.data.cancelled);
        verify(!f.c.deviceBusy("device-opaque"));
    }
    function test_missingExpiredOrMalformedStatusIsUnknownNotSuccessfulOrReplayable_data() {
        return [
            {tag: "missing-expired-foreign", operation: null, error: "No retained operation for this caller"},
            {tag: "missing-payload", operation: null, error: ""},
            {tag: "old-producer", operation: {request_id: "fixture-operation", state: "completed"}, error: ""},
            {tag: "wrong-id", operation: "wrong-id", error: ""},
            {tag: "wrong-target", operation: "wrong-target", error: ""}
        ];
    }
    function test_missingExpiredOrMalformedStatusIsUnknownNotSuccessfulOrReplayable(data) {
        const f = setup();
        receipt(f);
        f.r.poll();
        let operation = data.operation;
        if (operation === "wrong-id")
            operation = Object.assign({}, f.data.completed, {request_id: "another-operation"});
        if (operation === "wrong-target")
            operation = Object.assign({}, f.data.completed, {device_key: "another-device"});
        status(f, operation, data.error);
        verify(f.c.deviceBusy("device-opaque"), "unknown outcome retains its device guard");
        compare(f.c.activeOperations[f.data.queued.request_id].state, "unknown");
        verify(f.c.status.includes("Outcome unknown"));
        const count = calls.length;
        f.r.poll();
        receipt(f);
        event(f, f.data.progress);
        event(f, f.data.completed);
        snapshot(f, [f.data.started], [f.data.completed]);
        compare(calls.length, count, "uncertainty never dispatches another effect or automatic retry");
        compare(f.c.activeOperations[f.data.queued.request_id].state, "unknown");
        verify(f.c.status.includes("Outcome unknown"), "stale aggregate observations cannot relabel uncertainty as active/successful");
    }
    function test_stalledReadHasBoundedUncertaintyAndNeverOverlapsReads() {
        const f = setup();
        receipt(f);
        f.r.poll();
        const firstId = f.r.statusRequestId;
        const peer = Object.assign({}, f.data.queued, {request_id: "peer-operation", device_key: "peer-device"});
        receipt(f, peer);
        f.r.statusStarted = Date.now() - 5001;
        for (let i = 0; i < 5; ++i)
            f.r.poll();
        compare(calls.filter(call => call.method === "bluetooth.operation.status").length, 1);
        compare(f.r.statusRequestId, firstId);
        compare(f.c.activeOperations[f.data.queued.request_id].state, "unknown");
        compare(f.c.activeOperations[peer.request_id].state, "queued");
        status(f, f.data.completed); // Even late success cannot undo local uncertainty.
        compare(f.c.activeOperations[f.data.queued.request_id].state, "unknown");
        f.r.poll();
        compare(calls.filter(call => call.method === "bluetooth.operation.status").length, 2);
        compare(calls[calls.length - 1].params.request_id, peer.request_id);
        status(f, Object.assign({}, f.data.progress, {request_id: peer.request_id, device_key: peer.device_key}));
        verify(f.c.deviceBusy(peer.device_key));
    }
    function test_malformedEventsCannotConsumeRevisionOrRetargetWork() {
        const f = setup();
        receipt(f);
        for (const revision of [undefined, 0, -1, 1.5, 9007199254740992, "3"])
            event(f, Object.assign({}, f.data.progress, {revision: revision}));
        event(f, Object.assign({}, f.data.progress, {device_key: "foreign-device"}));
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 1);
        event(f, f.data.progress);
        compare(f.c.activeOperations[f.data.queued.request_id].revision, 3);
        verify(!f.c.deviceBusy("foreign-device"));
    }
    function test_reconnectRetiresReadsAndCannotApplyOldOwnerOutcomes() {
        const f = setup();
        receipt(f);
        f.r.poll();
        const oldId = f.r.statusRequestId;
        f.b.failSharedTransport("fixture-disconnect");
        compare(Object.keys(f.c.activeOperations).length, 0);
        compare(f.r.statusRequestId, "");
        f.b.acceptSharedResponse(oldId, f.data.status, "");
        event(f, f.data.progress);
        compare(Object.keys(f.c.activeOperations).length, 0);
        verify(f.c.status.includes("fixture-disconnect"));
    }
}
