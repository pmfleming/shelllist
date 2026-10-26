pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Wifi as Wifi

// Actual Qt consumer regressions. Transport is a private recording fake, not NM.
DaemonTestCase {
    id: testCase
    name: "WifiConnectRecovery"
    when: windowShown

    Component {
        id: controllerFactory
        Wifi.WifiController { prompt: Wifi.WifiPromptController {} }
    }
    function makeController() {
        const c = createTemporaryObject(controllerFactory, testCase);
        verify(c !== null);
        c.backend.pending = ({});
        calls = [];
        c.connection.requestId = "owned";
        return c;
    }
    function event(revision, name, data, id) {
        return {stream: "wifi.connect", request_id: id || "owned", operation_revision: revision,
            event: name, data: data || {message: "Native " + name}};
    }
    function status(revision, name, data) {
        return {stream: "wifi.connect", request_id: "owned", operation_revision: revision,
            status: ["started", "progress"].includes(name) ? "running" : "finished",
            event: event(revision, name, data), cancellation_requested: false};
    }
    function reply(c, result, id) {
        c.backend.acceptSharedResponse(id || c.connection.recoveryId,
            {protocol: "nm-api", version: 2, ok: true, data: {result: result}}, "");
    }
    function readCount() { return calls.filter(call => call.method === "operation.status").length; }
    function verifyNoEffects() {
        verify(calls.every(call => !["wifi.connectTarget", "wifi.qr.connect", "wifi.secret.provide"].includes(call.method)),
            "recovery never starts a connection or answers a secret prompt");
    }
    function test_quietFinalLossIsRecoveredByReadOnlyPolling() {
        const c = makeController();
        const poll = findChild(c.connection, "connectionRecoveryPoll");
        verify(!!poll);
        poll.interval = 20;
        tryVerify(() => readCount() === 1);
        verify(c.actionInFlight);
        reply(c, status(4, "succeeded", {result: {status: "connected", message: "Confirmed connection"}}));
        compare(c.connection.requestId, "");
        compare(c.status, "Confirmed connection");
        verify(!c.prompt.open && !c.prompt.credentialOpen);
        verifyNoEffects();
    }
    function test_deadlineRetainsOutstandingReadAndLateOutcomeCanStillConverge() {
        const c = makeController();
        const deadline = findChild(c.connection, "connectionRecoveryReplyDeadline");
        const poll = findChild(c.connection, "connectionRecoveryPoll");
        deadline.interval = 20;
        poll.interval = 20;
        verify(c.connection.checkStatus(true));
        const id = c.connection.recoveryId;
        tryCompare(c.connection, "recoveryTimedOut", true);
        verify(c.backend.isPending(id), "deadline cannot release transport read admission");
        wait(100);
        compare(readCount(), 1);
        verify(!c.connection.checkStatus(true));
        verify(c.actionInFlight, "unknown outcome retains the mutation guard");
        reply(c, status(3, "cancelled"), id);
        compare(c.connection.requestId, "");
        compare(c.connection.recoveryId, "");
        verify(!c.backend.isPending(id));
        const completedStatus = c.status;
        c.connection.statusTimedOut();
        compare(c.status, completedStatus, "a retired deadline cannot replace terminal evidence");
        verifyNoEffects();
    }
    function test_olderReadDuplicateAndReorderedEventsCannotReplaceNewerProgress() {
        const c = makeController();
        verify(c.connection.checkStatus(true));
        c.connection.handleEvent(event(5, "progress", {message: "Newest progress"}));
        reply(c, status(3, "progress", {message: "Old read"}));
        compare(c.status, "Newest progress");
        c.connection.handleEvent(event(5, "progress", {message: "Duplicate"}));
        c.connection.handleEvent(event(4, "failed"));
        c.connection.handleEvent(event(50, "cancelled", {}, "foreign"));
        compare(c.status, "Newest progress");
        compare(c.connection.operationRevision, 5);
        verify(c.actionInFlight);
        verify(c.connection.checkStatus(true));
        reply(c, status(6, "cancelled"));
        compare(c.connection.requestId, "");
        c.connection.handleEvent(event(7, "progress"));
        compare(c.connection.requestId, "", "terminal operation cannot reopen");
        verifyNoEffects();
    }
    function test_readCapturedBeforeCancelCannotRevokeCancellationIntent() {
        const c = makeController();
        verify(c.connection.checkStatus(true));
        c.connection.cancel();
        verify(c.connection.cancellationRequested);
        reply(c, status(2, "progress", {message: "Pre-cancel progress"}));
        verify(c.connection.cancellationRequested);
        verify(c.status.includes("cancellation acknowledgement"));
        c.connection.handleEvent(event(3, "progress", {message: "Late progress"}));
        verify(c.status.includes("cancellation acknowledgement"));
        verify(c.actionInFlight);
        c.connection.handleEvent(event(4, "cancelled"));
        compare(c.connection.requestId, "");
        verifyNoEffects();
    }
    function test_invalidOrOldProducerStatusRetainsAcceptedWork_data() {
        return [
            {tag: "unknown", value: {request_id: "owned", status: "unknown"}},
            {tag: "old-producer", value: {request_id: "owned", stream: "wifi.connect", status: "finished", event: event(undefined, "cancelled")}},
            {tag: "mismatched-revision", value: Object.assign(status(2, "cancelled"), {operation_revision: 3})},
            {tag: "running-terminal", value: Object.assign(status(2, "cancelled"), {status: "running"})},
            {tag: "finished-progress", value: Object.assign(status(2, "progress"), {status: "finished"})},
            {tag: "foreign-event", value: Object.assign(status(2, "cancelled"), {event: event(2, "cancelled", {}, "foreign")})},
            {tag: "malformed-event", value: Object.assign(status(2, "cancelled"), {event: event(2, "cancelled", [])})},
            {tag: "missing-success-result", value: status(2, "succeeded")},
            {tag: "malformed-failure-result", value: status(2, "failed", {result: false})},
            {tag: "contradictory-result", value: status(2, "failed", {result: {status: "connected", suggest_open_portal: true}})},
            {tag: "unsafe-revision", value: status(9007199254740992, "cancelled")}
        ];
    }
    function test_invalidOrOldProducerStatusRetainsAcceptedWork(data) {
        const c = makeController();
        verify(c.connection.checkStatus(true));
        reply(c, data.value);
        compare(c.connection.requestId, "owned");
        compare(c.connection.operationRevision, 0);
        compare(c.connection.recoveryId, "");
        compare(c.connection.recoveryFailures, 1);
        verify(c.actionInFlight);
        verify(c.status.includes("unconfirmed"));
        verifyNoEffects();
    }
    function test_threeCompletedReadFailuresStopAutomaticRetryButManualCheckRemains() {
        const c = makeController();
        const poll = findChild(c.connection, "connectionRecoveryPoll");
        poll.interval = 20;
        for (let attempt = 0; attempt < 3; attempt++) {
            verify(c.connection.checkStatus(attempt === 0));
            reply(c, {request_id: "owned", status: "unknown"});
        }
        compare(c.connection.recoveryFailures, 3);
        wait(100);
        compare(readCount(), 3);
        verify(c.actionInFlight);
        verify(c.connection.checkStatus(true));
        reply(c, status(2, "cancelled"));
        compare(c.connection.requestId, "");
        compare(readCount(), 4);
        verifyNoEffects();
    }
    function test_terminalRecoveryLeavesPrivateDraftAndObserversIntact() {
        const c = makeController();
        c.handleSecretEvent({event: "requested", request_id: "private-prompt", data: {secret_keys: ["psk"], timeout_ms: 60000}});
        c.prompt.credentialValues = ({psk: "synthetic-draft"});
        const observer = c.backend.sharedConsumerId;
        verify(c.connection.checkStatus(true));
        reply(c, status(3, "failed", {result: {status: "error", message: "Native failure",
            recovery_prompt: {kind: "password", message: "Advisory only"}}}));
        compare(c.connection.requestId, "");
        compare(c.backend.sharedConsumerId, observer);
        verify(c.prompt.credentialOpen);
        compare(c.prompt.secretRequestId, "private-prompt");
        compare(c.prompt.credentialValues.psk, "synthetic-draft");
        c.handleSecretEvent({event: "cancelled", request_id: "private-prompt", data: {reason: "activation-finished"}});
        verify(!c.prompt.credentialOpen);
        compare(c.prompt.credentialValues, ({}));
        c.connection.handleEvent(event(4, "failed", {recovery_prompt: {kind: "password"}}));
        verify(!c.prompt.credentialOpen && !c.prompt.open, "late recovery never reopens credentials");
        verifyNoEffects();
    }
    function test_transportLossRetiresReadAndLateReplyCannotAffectNextOperation() {
        const c = makeController();
        verify(c.connection.checkStatus(true));
        const oldRead = c.connection.recoveryId;
        c.backend.failSharedTransport("private fixture disconnect");
        compare(c.connection.requestId, "");
        compare(c.connection.recoveryId, "");
        c.connection.requestId = "replacement";
        reply(c, status(99, "succeeded", {result: {status: "connected"}}), oldRead);
        compare(c.connection.requestId, "replacement");
        compare(c.connection.operationRevision, 0);
        verify(c.actionInFlight);
        verifyNoEffects();
    }
}
