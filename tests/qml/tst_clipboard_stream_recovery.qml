pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../clipboard" as Clip

DaemonTestCase {
    id: testCase
    name: "ClipboardStreamRecovery"
    when: windowShown
    Component {
        id: factory
        Io.DaemonBackend {
            id: fixtureBackend
            daemonName: "clip-daemon"
            expectedProtocol: "clip-api"
            expectedVersion: 2
            streams: ["clipboard.history.changed", "clipboard.current.changed", "clipboard.operation"]
            active: true
            property var replies: []
            property var events: []
            property var discarded: []
            property var uncertain: []
            property int invalidations: 0
            requestPolicy: Io.ClipboardStateRecovery {
                backend: fixtureBackend
                onHistoryInvalidated: fixtureBackend.invalidations++
                onReadDiscarded: function(id) { fixtureBackend.discarded = fixtureBackend.discarded.concat([id]); }
                onOperationUncertain: function(id, message) { fixtureBackend.uncertain = fixtureBackend.uncertain.concat([id]); }
            }
            onResponseReceived: function(id, envelope, error) { replies = replies.concat([{id: id, value: envelope}]); }
            onEventReceived: function(event) { events = events.concat([event]); }
        }
    }
    Component { id: controllerFactory; Clip.ClipboardController {} }
    function init() { failOnWarning(/.*(TypeError|Binding loop|invalid context).*/); clientReady = true; calls = []; }
    function make() { const backend = createTemporaryObject(factory, testCase); verify(backend !== null); wait(0); return backend; }
    function stamp(revision, epoch) { return {epoch: epoch || "fixture-epoch", revision: revision}; }
    function history(revision) { return {_history: stamp(revision), history: {snapshot_revision: "content-token", entries: [], total: 0}}; }
    function operation(status, revision, id, action) { return {id: id || "owned", action: action || "annotate", status: status, message: status, _publication: stamp(revision)}; }
    function reply(backend, id, data, error) { backend.acceptSharedResponse(id, {protocol: "clip-api", version: 2, ok: !error, data: data, error: error ? {code: error, message: error} : undefined}, ""); }
    function event(backend, stream, name, data) { backend.acceptSharedEvent({protocol: "clip-api", version: 2, stream: stream, event: name, data: data}); }

    function test_historyFencesOldReadsResetLagMalformedMetadataAndSensitiveDetails() {
        const b = make();
        verify(b.call("old", "clipboard.history.query", {}));
        verify(b.call("new", "clipboard.history.query", {}));
        reply(b, "new", history(3));
        compare(b.replies.length, 1);
        event(b, "clipboard.history.changed", "reset", {_history: stamp(4), history_revision: "different"});
        reply(b, "old", history(2));
        compare(b.replies.length, 1);
        compare(b.discarded, ["old"]);
        event(b, "clipboard.current.changed", "changed", {_history: stamp(4)});
        event(b, "clipboard.history.changed", "reset", {_history: stamp(9, "retired")});
        compare(b.invalidations, 1);
        verify(b.call("lagged", "clipboard.history.query", {}));
        event(b, "clipboard.history.changed", "reset", {reason: "lagged"});
        reply(b, "lagged", history(4));
        compare(b.discarded, ["old", "lagged"]);
        verify(b.call("fresh", "clipboard.history.query", {}));
        reply(b, "fresh", history(4));
        compare(b.replies.length, 2, "equal-watermark queries are valid after a fresh request");
        verify(b.call("details", "clipboard.entry.details", {entry_id: "sensitive", revision: 1}));
        event(b, "clipboard.history.changed", "reset", {_history: stamp(5)});
        reply(b, "details", {entry: {entry: {id: "sensitive", revision: 1}, text: "private fixture"}});
        compare(b.discarded[2], "details");
        verify(b.call("incompatible", "clipboard.history.query", {}));
        reply(b, "incompatible", {history: {entries: [], snapshot_revision: "old"}});
        compare(b.replies[2].value.ok, false);
        compare(b.requestPolicy.historyRevision, 5);
    }
    function test_gracefulIdleShutdownPermitsNewEpochButFencesDrainedOldReads() {
        const b = make();
        b.call("before", "clipboard.history.query", {});
        reply(b, "before", history(8));
        b.call("draining", "clipboard.history.query", {});
        clientReady = false;
        compare(b.requestPolicy.historyEpoch, "");
        clientReady = true;
        b.call("reopened", "clipboard.history.query", {});
        reply(b, "reopened", Object.assign(history(1), {_history: stamp(1, "replacement")}));
        reply(b, "draining", history(8));
        compare(b.requestPolicy.historyEpoch, "replacement");
        compare(b.replies.length, 2);
        compare(b.discarded, ["draining"]);
        event(b, "clipboard.history.changed", "reset", {_history: stamp(9)});
        compare(b.requestPolicy.historyRevision, 1);
    }
    function test_ownedStatusRepairsQuietTerminalLossWithoutAffectingPeersOrReplaying() {
        const b = make();
        const peer = make();
        verify(b.call("effect", "clipboard.entry.action", {action: "annotate"}));
        reply(b, "effect", {operation: operation("started", 1)});
        event(peer, "clipboard.operation", "started", {operation: operation("started", 1)});
        compare(peer.events.length, 0, "socket owner sharing is not consumer operation ownership");
        calls = [];
        event(b, "clipboard.operation", "gap", {});
        compare(calls.length, 1);
        compare(calls[0].method, "clipboard.operation.status");
        compare(calls[0].params.operation_id, "owned");
        b.requestPolicy.poll();
        compare(calls.length, 1, "one status request outstanding");
        const id = b.requestPolicy.statusPending;
        reply(b, id, {operation: operation("completed", 2)});
        compare(b.replies.length, 2);
        event(b, "clipboard.operation", "started", {operation: operation("started", 1)});
        event(b, "clipboard.operation", "completed", {operation: operation("completed", 2)});
        compare(b.events.length, 0);
        b.requestPolicy.poll();
        compare(calls.length, 1);
        compare(Object.keys(peer.requestPolicy.operations).length, 0);
    }
    function test_uncertaintyStopsPollingAndRetiresLateResultsWithoutReplayingEffects_data() {
        return [{tag: "expired", deadline: false}, {tag: "deadline", deadline: true}];
    }
    function test_uncertaintyStopsPollingAndRetiresLateResultsWithoutReplayingEffects(data) {
        const b = make();
        b.call("effect", "clipboard.capture.interactive", {mode: "region"});
        reply(b, "effect", {operation: operation("started", 1, "owned", "screenshot")});
        b.requestPolicy.poll();
        if (data.deadline) {
            b.requestPolicy.statusPendingSince = 0;
            b.requestPolicy.poll();
        } else reply(b, b.requestPolicy.statusPending, {}, "operation-unknown");
        compare(b.uncertain, ["owned"]);
        if (data.deadline) {
            reply(b, b.requestPolicy.statusPending, {operation: operation("completed", 2, "owned", "screenshot")});
            compare(b.replies.length, 1, "a late status cannot silently resolve a retired outcome");
        }
        const count = calls.length;
        event(b, "clipboard.operation", "completed", {operation: operation("completed", 2, "owned", "screenshot")});
        b.requestPolicy.poll();
        compare(calls.length, count);
        compare(b.events.length, 0);
        b.failSharedTransport("gone");
        compare(Object.keys(b.requestPolicy.operations).length, 0);
        compare(b.requestPolicy.historyEpoch, "");
        compare(calls.length, count);
    }
    function test_malformedOperationCannotBecomePasteOrConsumeAValidStamp() {
        const b = make();
        b.call("effect", "clipboard.entry.action", {action: "annotate"});
        reply(b, "effect", {operation: operation("started", 1)});
        event(b, "clipboard.operation", "completed", {operation: operation("paste-prepared", 2, "owned", "paste")});
        compare(b.events.length, 0);
        compare(b.uncertain, ["owned"]);
        compare(b.requestPolicy.operations.owned.revision, 1);
        b.call("bad", "clipboard.entry.action", {action: "paste"});
        reply(b, "bad", {operation: {id: "bad", action: "paste", status: "paste-prepared"}});
        compare(b.replies[1].value.ok, false);
        compare(b.requestPolicy.operations.bad, undefined);
    }
    function test_operationRecoveryPreservesControllerDraftsAndAcceptedGuards() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        controller.uiActive = true;
        wait(0);
        const b = findChild(controller, "clipboardBackend");
        controller.detailState.editDraft = "private unsaved draft";
        b.call("action-annotate", "clipboard.entry.action", {action: "annotate"});
        reply(b, "action-annotate", {operation: operation("started", 1)});
        verify(controller.actionInFlight);
        calls = [];
        event(b, "clipboard.operation", "gap", {});
        verify(controller.actionInFlight);
        compare(controller.activeOperationId, "owned");
        compare(controller.detailState.editDraft, "private unsaved draft");
        reply(b, b.requestPolicy.statusPending, {}, "operation-unknown");
        verify(!controller.actionInFlight);
        compare(controller.detailState.editDraft, "private unsaved draft");
        verify(controller.status.indexOf("unknown") >= 0);
        verify(calls.every(call => call.method === "clipboard.operation.status"));
    }
}
