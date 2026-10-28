pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "DaemonSubscriptionCleanup"
    when: windowShown
    property var savedFactory
    property var savedSessions
    property var backend
    property var session
    property var peerBackend: null
    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: true
            property bool blocked: false
            property bool uncertainWrite: false
            property string writeDetail: "write status unknown"
            property bool uncertainSubscribe: false
            property var subscriptions: []
            property var controls: []
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            signal ownerRetired()
            signal requestUnsent(string id, string message, var route)
            function subscribeExtra(id, streams, route) {
                subscriptions = subscriptions.concat([{id: id, route: route}]);
                if (uncertainSubscribe) throw new Error("write status unknown");
            }
            function cancel(id, target, route) {
                if (blocked) throw new Error("UNSENT: full controls");
                controls = controls.concat([{id: id, target: target, route: route}]);
                if (uncertainWrite) throw new Error(writeDetail);
            }
            function release(id, route) {
                if (blocked) throw new Error("UNSENT: full controls");
                controls = controls.concat([{id: id, route: route}]);
            }
            function discardQueued(id) {}
            function recover(message) { transportFailed(message); }
        }
    }
    Component {
        id: backendFactory
        Io.DaemonBackend {
            daemonName: "cleanup-daemon"; active: true; streams: ["state.changed"]
            expectedProtocol: "test-api"; expectedVersion: 1
            property int events: 0
            property int failures: 0
            onEventReceived: events++
            onTransportFailed: failures++
        }
    }
    function init() {
        savedFactory = Io.DaemonSessions.clientFactory;
        savedSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
        backend = backendFactory.createObject(testCase);
        session = Io.DaemonSessions.sessions["cleanup-daemon"];
    }
    function cleanup() {
        if (backend) backend.destroy();
        if (peerBackend) peerBackend.destroy();
        peerBackend = null;
        wait(0);
        session.client.destroy();
        Io.DaemonSessions.sessions = savedSessions;
        Io.DaemonSessions.clientFactory = savedFactory;
    }
    function acknowledge(request, nativeId) {
        session.client.response(request.id, {protocol: "test-api", version: 1, ok: true, data: {subscription: {id: nativeId}}}, "", request.route);
    }
    function cleanupReply(control, ok) {
        session.client.response(control.id, ok ? {protocol: "test-api", version: 1, ok: true, data: {cancelled: control.target, kind: "subscription"}} : {ok: false}, "", control.route);
    }
    function cleanupRecords() { return Object.values(session.resources); }
    function test_receiptCannotBorrowPeerResource_data() {
        const valid = {protocol: "test-api", version: 1, ok: true, data: {subscription: {id: "peer-resource"}}};
        const variants = [
            {tag: "failure", value: Object.assign({}, valid, {ok: false, error: {code: "denied", message: "denied"}})},
            {tag: "missing-ok", value: {protocol: "test-api", version: 1, data: valid.data}},
            {tag: "wrong-protocol", value: Object.assign({}, valid, {protocol: "other-api"})},
            {tag: "wrong-version", value: Object.assign({}, valid, {version: 2})},
            {tag: "missing-version", value: {protocol: "test-api", ok: true, data: valid.data}},
            {tag: "error-on-success", value: Object.assign({}, valid, {error: {code: "denied", message: "denied"}})}
        ];
        let rows = [];
        for (const row of variants)
            for (const detached of [false, true])
                rows.push({tag: row.tag + (detached ? "-detached" : "-live"), value: row.value, detached: detached});
        return rows;
    }
    function test_receiptCannotBorrowPeerResource(data) {
        const request = session.client.subscriptions[0];
        peerBackend = backendFactory.createObject(testCase);
        acknowledge(session.client.subscriptions[1], "peer-resource");
        if (data.detached) {
            backend.destroy();
            backend = null;
            wait(0);
        }
        session.client.response(request.id, data.value, "", request.route);
        const record = session.resources[request.id];
        verify(!!record, "unknown registration responsibility is retained");
        compare(record.nativeId, "", "failed/invalid data cannot grant authority over the peer's resource");
        compare(record.state, "uncertain");
        verify(!session.client.controls.some(row => row.target === "peer-resource"));
        compare(session.consumers[peerBackend.sharedConsumerId].baseSubscriptionId, "peer-resource");
        if (backend) compare(session.consumers[backend.sharedConsumerId].baseSubscriptionId, "");
    }
    function test_cancellationReceiptCannotBorrowSuccess_data() {
        const valid = {protocol: "test-api", version: 1, ok: true, data: {cancelled: "native-base", kind: "subscription"}};
        return [
            {tag: "wrong-protocol", value: Object.assign({}, valid, {protocol: "other-api"})},
            {tag: "wrong-version", value: Object.assign({}, valid, {version: 2})},
            {tag: "missing-protocol", value: {ok: true, version: 1, data: valid.data}},
            {tag: "wrong-disposition", value: Object.assign({}, valid, {data: {cancelled: "native-base", kind: "operation"}})},
            {tag: "error-on-success", value: Object.assign({}, valid, {error: {code: "denied", message: "denied"}})}
        ];
    }
    function test_cancellationReceiptCannotBorrowSuccess(data) {
        acknowledge(session.client.subscriptions[0], "native-base");
        verify(backend.renewBaseSubscription());
        const control = session.client.controls[0];
        session.client.response(control.id, data.value, "", control.route);
        const record = cleanupRecords().find(row => row.nativeId === "native-base");
        verify(!!record, "malformed cancellation receipt cannot discharge responsibility");
        compare(record.state, "uncertain");
        compare(session.generation, 0);
    }
    function test_frameworkReleaseReceiptIsNotADomainEnvelopeOrEffectOutcome() {
        peerBackend = backendFactory.createObject(testCase, {active: false});
        const consumerId = peerBackend.sharedConsumerId;
        peerBackend.destroy();
        peerBackend = null;
        wait(0);
        const control = session.client.controls.find(row => row.route.consumerId === consumerId);
        verify(!!control && control.target === undefined);
        session.client.response(control.id, {protocol: "test-api", version: 1, ok: true, data: {released: 0}}, "", control.route);
        verify(cleanupRecords().some(row => row.consumerId === consumerId && row.state === "uncertain"));
        session.client.response(control.id, {released: 0}, "", control.route);
        verify(!cleanupRecords().some(row => row.consumerId === consumerId));
        verify(backend.active, "framework subscription release is not peer/effect completion");
    }
    function test_receiptContractAndOriginalRequestWindowAreCaptured() {
        const request = session.client.subscriptions[0];
        const envelope = {protocol: "test-api", version: 1, ok: true, data: {subscription: {id: "native-base"}}};
        session.client.response(request.id, envelope, "", Object.assign({}, request.route, {localId: "other-window"}));
        compare(session.resources[request.id].state, "pending");
        compare(session.resources[request.id].nativeId, "");
        acknowledge(request, "native-base");
        backend.expectedVersion = 2;
        verify(backend.renewBaseSubscription());
        cleanupReply(session.client.controls[0], true);
        verify(!cleanupRecords().some(row => row.nativeId === "native-base"), "replacement contract cannot overwrite captured cleanup receipt identity");
    }
    function test_extraReleaseSurvivesQueuedExpiryAndFencesOldAttempt() {
        const id = backend.subscribeStreams(["extra.changed"]);
        acknowledge(session.client.subscriptions[1], "native-extra");
        verify(backend.unsubscribeStreams(id));
        const old = session.client.controls[0];
        session.client.requestUnsent(old.id, "UNSENT: queue expired", old.route);
        tryVerify(() => session.client.controls.length === 2);
        const replacement = session.client.controls[1];
        compare(replacement.target, "native-extra");
        verify(old.id !== replacement.id);
        cleanupReply(old, true);
        verify(cleanupRecords().some(row => row.nativeId === "native-extra"));
        cleanupReply(replacement, true);
        verify(!cleanupRecords().some(row => row.nativeId === "native-extra"));
        compare(session.generation, 0);
    }
    function test_cancelBeforeAckAndDetachDoNotLoseResources() {
        const id = backend.subscribeStreams(["extra.changed"]);
        verify(backend.unsubscribeStreams(id));
        acknowledge(session.client.subscriptions[1], "late-extra");
        compare(session.client.controls[0].target, "late-extra");
        cleanupReply(session.client.controls[0], true);
        compare(backend.pendingCount, 0);
        compare(Object.keys(backend.extraSubscriptions).length, 0);
        const detached = backendFactory.createObject(testCase) as Io.DaemonBackend;
        const request = session.client.subscriptions[2];
        const consumerId = detached.sharedConsumerId;
        detached.destroy();
        wait(0);
        verify(!session.consumers[consumerId]);
        acknowledge(request, "late-detached");
        const control = session.client.controls.find(row => row.target === "late-detached");
        verify(!!control);
        cleanupReply(control, true);
        compare(session.client.controls.filter(row => row.target === "late-detached").length, 1);
        verify(!cleanupRecords().some(row => row.nativeId === "late-detached"));
        compare(session.generation, 0);
    }
    function test_unclassifiedWriteExceptionIsNotNeverWrittenRetryAuthority() {
        acknowledge(session.client.subscriptions[0], "native-base");
        session.client.uncertainWrite = true;
        verify(backend.renewBaseSubscription());
        const control = session.client.controls[0];
        compare(cleanupRecords().find(row => row.nativeId === "native-base").state, "uncertain");
        wait(220);
        compare(session.client.controls.length, 1);
        cleanupReply(control, true);
        verify(!cleanupRecords().some(row => row.nativeId === "native-base"));
        compare(session.generation, 0);
    }
    function test_embeddedUnsentTextCannotAuthorizeCleanupReplay() {
        acknowledge(session.client.subscriptions[0], "native-base");
        session.client.uncertainWrite = true;
        session.client.writeDetail = "write may have happened; nested diagnostic UNSENT: full";
        verify(backend.renewBaseSubscription());
        const record = cleanupRecords().find(row => row.nativeId === "native-base");
        compare(record.state, "uncertain", "quoted admission text is not proof that this attempt was never written");
        wait(220);
        compare(session.client.controls.length, 1, "uncertain cleanup must not replay");
        compare(session.generation, 0);
    }
    function test_unknownSubscribeWriteRetainsLateCleanupButNoPendingView() {
        session.client.uncertainSubscribe = true;
        compare(backend.subscribeStreams(["extra.changed"]), "");
        const request = session.client.subscriptions[1];
        compare(session.resources[request.id].state, "uncertain");
        compare(backend.pendingCount, 0);
        acknowledge(request, "late-write-resource");
        compare(session.client.controls[0].target, "late-write-resource");
        compare(Object.keys(backend.extraSubscriptions).length, 0);
        cleanupReply(session.client.controls[0], true);
    }
    function test_identityAndStringReservationsRejectBeforeTransportAdmission() {
        let unsent = false;
        try { Io.DaemonSessions.subscribe("cleanup-daemon", backend.sharedConsumerId, "x".repeat(513), [], false); }
        catch (error) { unsent = String(error).includes("UNSENT:"); }
        verify(unsent);
        compare(cleanupRecords().length, 2);
        compare(session.client.subscriptions.length, 1);
        backend.subscriptionSequence = 2147483647;
        compare(backend.subscribeStreams([]), "");
        compare(session.client.subscriptions.length, 1);
    }
    function test_lateClosedExtraCannotRestoreViewOrEventAuthority() {
        const id = backend.subscribeStreams(["extra.changed"]);
        const request = session.client.subscriptions[1];
        backend.active = false;
        acknowledge(request, "closed-extra");
        compare(backend.pendingCount, 0);
        compare(Object.keys(backend.extraSubscriptions).length, 0);
        compare(session.client.controls[0].target, "closed-extra");
        session.client.eventReceived({stream: "extra.changed", event: "changed", data: {}, subscription_id: "closed-extra"}, request.route);
        compare(backend.events, 0);
        cleanupReply(session.client.controls[0], true);
        verify(!cleanupRecords().some(row => row.nativeId === "closed-extra"));
    }
    function test_failureAndAbsenceStayChargedUntilOwnerRetirement() {
        acknowledge(session.client.subscriptions[0], "native-base");
        verify(backend.renewBaseSubscription());
        const control = session.client.controls[0];
        cleanupReply(control, false);
        const record = cleanupRecords().find(row => row.nativeId === "native-base");
        compare(record.state, "uncertain");
        wait(220);
        compare(session.client.controls.length, 1, "native failure does not authorize retry");
        // Exact late cancellation acknowledgement may reconcile the resource.
        cleanupReply(control, true);
        verify(!cleanupRecords().includes(record));
        const old = session.client.subscriptions[1];
        session.client.response(old.id, null, "outcome unknown", old.route);
        compare(session.resources[old.id].state, "uncertain");
        acknowledge(old, "late-unknown");
        compare(session.consumers[backend.sharedConsumerId].baseSubscriptionId, "");
        compare(session.client.controls[1].target, "late-unknown");
        session.client.transportFailed("view authority failed before physical exit");
        compare(session.generation, 1);
        verify(cleanupRecords().some(row => row.nativeId === "late-unknown"), "failure notification is not physical retirement");
        session.client.ownerRetired();
        compare(session.generation, 2);
        verify(!cleanupRecords().some(row => row.nativeId));
        acknowledge(old, "retired-native-id");
        compare(session.client.controls.length, 2, "no retired IDs transfer into new owner");
    }
    function test_bookkeepingReservedBeforeAdmissionAndNeverEvictsUnknown() {
        for (let i = 0; i < 254; i++) {
            verify(backend.subscribeStreams(["extra.changed"]).length > 0);
            const request = session.client.subscriptions[i + 1];
            session.client.response(request.id, null, "outcome unknown", request.route);
        }
        compare(cleanupRecords().length, 256);
        compare(backend.subscribeStreams(["overflow.changed"]), "");
        compare(session.client.subscriptions.length, 255, "overflow never enters transport");
        compare(cleanupRecords().filter(row => row.state === "uncertain").length, 254);
        compare(session.generation, 0);
    }
    function test_detachedReleaseSurvivesFullControlQueueWithoutRetiringPeer() {
        acknowledge(session.client.subscriptions[0], "peer-base");
        peerBackend = backendFactory.createObject(testCase, {active: false});
        const detachedId = peerBackend.sharedConsumerId;
        session.client.blocked = true;
        peerBackend.destroy();
        peerBackend = null;
        wait(220);
        verify(!session.consumers[detachedId]);
        const record = cleanupRecords().find(row => row.consumerId === detachedId);
        verify(!!record, "detachment cannot discard an unsent release");
        compare(record.kind, "release");
        compare(record.state, "cleanup");
        compare(session.client.controls.length, 0);
        compare(session.generation, 0);
        compare(session.consumers[backend.sharedConsumerId].baseSubscriptionId, "peer-base");
        session.client.blocked = false;
        tryVerify(() => session.client.controls.length === 1);
        const control = session.client.controls[0];
        compare(control.route.consumerId, detachedId);
        compare(control.target, undefined);
        verify(cleanupRecords().includes(record), "sending is not a release acknowledgement");
        session.client.response(control.id, {released: 0}, "", control.route);
        verify(!cleanupRecords().includes(record));
        compare(session.generation, 0);
        compare(session.consumers[backend.sharedConsumerId].baseSubscriptionId, "peer-base");
    }
    function test_renewalRetainsExactResourceThroughUnsent() {
        acknowledge(session.client.subscriptions[0], "native-base");
        session.client.blocked = true;
        verify(backend.renewBaseSubscription());
        compare(session.generation, 0, "local UNSENT must not retire healthy owner");
        session.client.blocked = false;
        tryVerify(() => session.client.controls.some(row => row.target === "native-base"));
        compare(session.client.controls.filter(row => row.target === "native-base").length, 1);
    }
}
