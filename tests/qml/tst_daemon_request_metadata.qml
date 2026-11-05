pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io

// Real shared routing, with only the transport substituted. Completion callbacks
// may reuse a local ID; the retiring request must not consume its replacement.
TestCase {
    id: tests
    name: "DaemonRequestMetadata"
    when: windowShown
    property var originalFactory
    property var originalSessions
    property var backend
    property var client
    property var replies: []
    property var unsentReplies: []
    property var policyUnsent: []
    property bool reuseId: false
    property bool consumeMetadata: false

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: true
            property var calls: []
            property bool rejectSend: false
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal ownerRetired()
            signal transportFailed(string message)
            signal requestUnsent(string id, string message, var route)
            function discardQueued(consumerId) {}
            function call(id, method, params, route) {
                if (rejectSend) throw new Error("UNSENT: inert admission failure");
                calls = calls.concat([{id: id, method: method, route: route}]);
            }
            function subscribeExtra(id, streams, route) {}
            function cancel(id, requestId, route) {}
            function release(id, route) {}
            function recover(message) { transportFailed(message); }
        }
    }
    Component {
        id: backendFactory
        Io.DaemonBackend {
            daemonName: "metadata-test"
            active: false
            expectedProtocol: "test-api"
            expectedVersion: 1
            function classifyRequest(method: string, params: var): var {
                return {kind: "control", method: "forged", target: params.target};
            }
            onSendFailed: (id, message) => tests.unsentReplies = tests.unsentReplies.concat([{id: id, message: message, metadata: requestMetadata[id]}])
            onResponseReceived: (id, envelope, error) => {
                tests.replies = tests.replies.concat([{id: id, envelope: envelope, error: error, metadata: requestMetadata[id]}]);
                if (tests.consumeMetadata)
                    forgetRequestMetadata(id, requestMetadata[id]);
                if (tests.reuseId) {
                    tests.reuseId = false;
                    call(id, "next.read", {target: "new-target"});
                }
            }
        }
    }
    QtObject {
        id: policy
        property bool replaceDuringReceipt: false
        function sending(id, method, params) { return params; }
        function sendFailed(id) { tests.policyUnsent = tests.policyUnsent.concat([id]); }
        function reset(message) {}
        function received(id, envelope, error) {
            if (replaceDuringReceipt) {
                replaceDuringReceipt = false;
                tests.backend.call(id, "fresh.read", {target: "fresh-target"});
            }
            return envelope;
        }
    }

    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.clientFactory = clientFactory;
        Io.DaemonSessions.sessions = ({});
    }
    function init() {
        replies = []; unsentReplies = []; policyUnsent = []; reuseId = false; consumeMetadata = false;
        policy.replaceDuringReceipt = false;
        backend = backendFactory.createObject(tests);
        verify(backend !== null);
        client = Io.DaemonSessions.sessions[backend.daemonName].client;
    }
    function cleanup() {
        backend.destroy(); wait(0);
        client.destroy();
        Io.DaemonSessions.sessions = ({});
        wait(0);
    }
    function cleanupTestCase() {
        Io.DaemonSessions.clientFactory = originalFactory;
        Io.DaemonSessions.sessions = originalSessions;
    }
    function reply() {
        const request = client.calls[client.calls.length - 1];
        client.response(request.id, {protocol: "test-api", version: 1, ok: true, data: {}}, "", request.route);
    }
    function test_reentrantIdKeepsNewMetadata() {
        verify(backend.call("same", "typed.read", {target: "old-target"}));
        reuseId = true;
        reply();
        compare(replies[0].metadata.method, "typed.read");
        verify(backend.isPending("same"));
        compare(backend.requestMetadata.same.method, "next.read");
        compare(backend.requestMetadata.same.target, "new-target");
        reply();
        compare(Object.keys(backend.requestMetadata).length, 0);
    }
    function test_pendingNotificationCannotReclassifySubmittedCall() {
        verify(backend.call("subscribe-1", "typed.read", {target: "original-target"}));
        let replace = true;
        backend.pendingChanged.connect(function() {
            if (replace && !backend.isPending("subscribe-1")) {
                replace = false;
                compare(backend.subscribeStreams(["updates"]), "subscribe-1");
            }
        });
        reply();
        compare(replies.length, 1);
        compare(replies[0].metadata.method, "typed.read");
        compare(replies[0].metadata.target, "original-target");
        verify(backend.isPending("subscribe-1"));
        compare(backend.requestMetadata["subscribe-1"].kind, "subscription");
    }
    function test_queuedUnsentUsesCapturedRouteAndRetainsReentrantReplacement() {
        backend.requestPolicy = policy;
        verify(backend.call("same", "typed.read", {target: "queued-original"}));
        const original = client.calls[0];
        client.requestUnsent(original.id, "UNSENT: stale generation", Object.assign({}, original.route, {generation: original.route.generation - 1}));
        verify(backend.isPending("same"));
        compare(unsentReplies.length, 0);
        let replace = true;
        backend.pendingChanged.connect(function() {
            if (replace && !backend.isPending("same")) {
                replace = false;
                verify(backend.call("same", "fresh.read", {target: "fresh-target"}));
            }
        });
        client.requestUnsent(original.id, "UNSENT: admission deadline", original.route);
        compare(policyUnsent, ["same"]);
        compare(unsentReplies, [{id: "same", message: "UNSENT: admission deadline",
            metadata: {kind: "call", method: "typed.read", target: "queued-original"}}]);
        compare(replies.length, 0, "never-written work is not a dispatched uncertainty response");
        verify(backend.isPending("same"));
        compare(backend.requestMetadata.same.method, "fresh.read");
        compare(backend.requestMetadata.same.target, "fresh-target");
        compare(client.calls.length, 2, "only explicit replacement, never automatic replay");
    }
    function test_synchronousUnsentKeepsCompletingFailureTargetAndReplacement() {
        backend.requestPolicy = policy;
        client.rejectSend = true;
        let replace = true;
        backend.pendingChanged.connect(function() {
            if (replace && !backend.isPending("same")) {
                replace = false;
                client.rejectSend = false;
                verify(backend.call("same", "fresh.read", {target: "fresh-target"}));
            }
        });
        verify(!backend.call("same", "typed.read", {target: "original-target"}));
        compare(unsentReplies.length, 1);
        compare(unsentReplies[0].metadata.method, "typed.read");
        compare(unsentReplies[0].metadata.target, "original-target");
        verify(backend.isPending("same"));
        compare(backend.requestMetadata.same.method, "fresh.read");
        compare(backend.requestMetadata.same.target, "fresh-target");
        compare(policyUnsent, ["same"]);
        compare(client.calls.length, 1);
    }
    function test_consumingOldMetadataCannotErasePolicyCallbackReplacement() {
        backend.requestPolicy = policy;
        consumeMetadata = true;
        verify(backend.call("same", "typed.read", {target: "original-target"}));
        policy.replaceDuringReceipt = true;
        reply();
        compare(replies[0].metadata.method, "typed.read");
        compare(replies[0].metadata.target, "original-target");
        verify(backend.isPending("same"));
        verify(!!backend.requestMetadata.same);
        compare(backend.requestMetadata.same.method, "fresh.read");
        compare(backend.requestMetadata.same.target, "fresh-target");
        reply();
        verify(!backend.isPending("same"));
        compare(backend.requestMetadata.same, undefined);
    }
}
