import QtQuick
import QtTest
import "imports/Quickshell" as QuickshellFixture
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "DaemonSocket"
    when: windowShown
    Component {
        id: factory
        Io.JsonlDaemonClient {
            daemonName: "bt-daemon"
            useSocket: true
            socketPath: "/isolated/bt-daemon.sock"
            active: false
            streams: []
            automaticSubscribe: false
            recoverProtocolErrors: true
            initialRetryInterval: 60000
            maximumRetryInterval: 60000
            property int failures: 0
            property var replies: []
            property var unsent: []
            onRequestUnsent: function(id, message, route) {
                unsent = unsent.concat([{id: id, message: message, route: route}]);
            }
            onTransportFailed: failures++
            onResponse: function(id, envelope, error, route) {
                replies = replies.concat([{id: id, envelope: envelope, error: error, route: route}]);
            }
        }
    }
    Component {
        id: eagerFactory
        Io.JsonlDaemonClient {
            active: true
            daemonName: "bt-daemon"
            useSocket: true
            socketPath: "/isolated/bt-daemon.sock"
            streams: []
            automaticSubscribe: false
            recoverProtocolErrors: true
        }
    }
    Component {
        id: optInFactory
        Io.JsonlDaemonClient {
            daemonName: "nm-daemon"
            active: false
            streams: []
            recoverProtocolErrors: true
            automaticSubscribe: false
        }
    }
    function test_optInsAreExplicitAndDaemonScoped() {
        const original = QuickshellFixture.Quickshell.environment;
        try {
            const flags = {"nm-daemon":"SHELLLIST_NM_SOCKET", "bt-daemon":"SHELLLIST_BT_SOCKET", "app-daemon":"SHELLLIST_APP_SOCKET", "bar-daemon":"SHELLLIST_BAR_SOCKET", "bar-notification-daemon":"SHELLLIST_BAR_SOCKET", "bar-power-daemon":"SHELLLIST_BAR_SOCKET", "bar-compositor-daemon":"SHELLLIST_BAR_SOCKET", "bar-activity-daemon":"SHELLLIST_BAR_SOCKET", "clip-daemon":"SHELLLIST_CLIP_SOCKET"};
            for (const enabled of [""].concat(Object.values(flags))) {
                for (const value of ["", "0", "true", "1"]) {
                    QuickshellFixture.Quickshell.environment = Object.assign({XDG_RUNTIME_DIR: "/isolated"}, enabled ? {[enabled]: value} : {});
                    for (const daemon of Object.keys(flags)) {
                        const client = createTemporaryObject(optInFactory, testCase, {daemonName: daemon}) as Io.JsonlDaemonClient;
                        verify(client !== null);
                        compare(client.useSocket, flags[daemon] === enabled && value === "1");
                        compare(client.socketPath, "/isolated/" + daemon + ".sock");
                        const transport = findChild(client, "daemonSocketTransport");
                        compare(transport.maximumPendingBytes, daemon === "bar-daemon" ? 3 * (32 * 1024 * 1024 + 1) : daemon === "clip-daemon" ? 3 * (128 * 1024 * 1024 + 1) : 4 * 1024 * 1024);
                        compare(transport.maximumCalls, daemon === "clip-daemon" ? 4 : 64);
                    }
                }
            }
        } finally {
            QuickshellFixture.Quickshell.environment = original;
        }
    }
    function test_declarativeStartupWaitsForAllBindings() {
        const client = createTemporaryObject(eagerFactory, testCase) as Io.JsonlDaemonClient;
        verify(client !== null);
        verify(client.componentReady);
        verify(client.ready);
        compare(findChild(client, "daemonBridgeProcess").commands.length, 0);
    }
    function test_recoveryDestroysSocketBeforeBackoffWithoutReplaying() {
        const f = fixture();
        f.client.initialRetryInterval = 1;
        f.client.maximumRetryInterval = 1;
        f.client.call("effect", "effect.once", {});
        f.client.recover("injected invalid generation");
        verify(!f.transport.running);
        compare(f.transport.pendingBytes, 0);
        tryCompare(f.client, "ready", true);
        compare(f.transport.endpoint.writes.length, 0);
        compare(f.client.failures, 1);
    }
    function fixture() {
        const client = createTemporaryObject(factory, testCase);
        verify(client !== null);
        const transport = findChild(client, "daemonSocketTransport");
        verify(transport !== null);
        client.active = true;
        verify(client.ready);
        verify(!transport.connectDeadline.running, "synchronous connect must disarm deadline");
        compare(findChild(client, "daemonBridgeProcess").commands.length, 0);
        return {client: client, transport: transport};
    }
    function wireId(transport, id) {
        return Object.keys(transport.pending).find(key => transport.pending[key].id === id);
    }
    function reply(transport, id, response, route) {
        const key = id === transport.shutdownId ? id : wireId(transport, id);
        transport.endpoint.deliver(JSON.stringify({kind: "response", id: key, ok: true, response: response, route: route}));
    }
    function test_responseAndRoutePreserveWireAndReleaseWindow() {
        const f = fixture();
        const route = {consumerId: "view", localId: "read", generation: 4, kind: "call"};
        f.client.call("read", "bluetooth.snapshot", {}, route);
        const message = JSON.parse(f.transport.endpoint.writes[0]);
        compare(message.route, route);
        compare(f.transport.pendingCalls, 1);
        reply(f.transport, "read", {ok: true}, route);
        compare(f.client.replies.length, 1);
        compare(f.client.replies[0].route, route);
        compare(f.transport.pendingCalls, 0);
        compare(f.transport.pendingBytes, 0);
    }
    function test_backpressureReservesControlsAndNeverReplaysFailedEffects() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.maximumControls = 1;
        f.transport.maximumQueuedRequests = 0;
        f.transport.maximumQueuedControls = 0;
        f.client.call("effect", "effect.once", {});
        f.transport.maximumPendingBytes = f.transport.pendingBytes;
        let rejected = false;
        try { f.client.call("overflow", "effect.once", {}); } catch (error) { rejected = true; }
        verify(rejected);
        f.client.cancel("cancel", "owned-operation", {consumerId: "view", localId: "cleanup", kind: "control", generation: 0}, true);
        compare(f.transport.endpoint.writes.length, 2);
        verify(f.transport.pendingControlBytes > 0, "controls retain bytes even when call budget is full");
        rejected = false;
        try { f.client.cancel("cancel-two", "owned-operation"); } catch (error) { rejected = true; }
        verify(rejected);
        f.client.initialRetryInterval = 1;
        f.client.maximumRetryInterval = 1;
        f.transport.endpoint.error(1);
        tryCompare(f.client, "failures", 1);
        tryCompare(f.client, "ready", true);
        compare(f.transport.pendingBytes, 0);
        compare(f.transport.pendingControlBytes, 0);
        compare(f.transport.endpoint.writes.length, 0, "failed-generation effects are not replayed");
    }
    function test_closeDrainsRepliesAndNeverTransfersQueueToFreshGeneration() {
        const f = fixture();
        f.client.call("old", "effect.once", {});
        const old = f.transport.endpoint;
        f.client.active = false;
        compare(f.client.lifecycle, "stopping");
        compare(JSON.parse(old.writes[1]).op, "shutdown");
        f.client.active = true;
        let rejected = false;
        try { f.client.call("new", "effect.once", {}); } catch (error) { rejected = true; }
        verify(rejected, "closing owner must not queue effects for a replacement");
        compare(old.writes.length, 2);
        reply(f.transport, "old", {ok: true}, null);
        compare(f.client.replies.length, 1);
        reply(f.transport, f.transport.shutdownId, {shutdown: true}, null);
        tryCompare(f.client, "ready", true);
        compare(f.client.failures, 0);
        compare(f.transport.endpoint.writes.length, 0);
        f.client.call("explicit-new", "effect.once", {});
        compare(f.transport.endpoint.writes.length, 1);
        compare(f.transport.pendingCalls, 1);
    }
    function test_subscribeSharesDataLaneAndCleanupBypassesWaitingData() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.maximumQueuedRequests = 1;
        const route = {consumerId: "view", localId: "read", kind: "call", generation: 7};
        f.client.call("read", "state.get", {target: "captured"}, route);
        f.client.subscribeExtra("watch", ["state.changed"], {consumerId: "other", localId: "watch", kind: "subscription", generation: 7});
        compare(f.transport.pendingCalls, 1);
        compare(f.transport.pendingControls, 0);
        compare(f.transport.queue.length, 1);
        let rejected = false;
        try { f.client.call("overflow", "effect.once", {}); } catch (error) { rejected = String(error).includes("UNSENT"); }
        verify(rejected);
        f.client.cancel("cancel", "owned-id");
        compare(f.transport.pendingControls, 1);
        compare(f.transport.endpoint.writes.length, 2);
        route.generation = 99;
        reply(f.transport, "read", {ok: true}, {consumerId: "view", localId: "read", kind: "call", generation: 7});
        compare(f.transport.endpoint.writes.length, 3);
        compare(JSON.parse(f.transport.endpoint.writes[2]).op, "subscribe");
        compare(f.transport.pendingCalls, 1);
        compare(f.client.failures, 0);
    }
    function test_waitingDeadlineIsUnsentAndNeverRetiresHealthyOwner() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.queueTimeout = 10;
        f.client.call("accepted", "effect.once", {});
        const acceptedBytes = f.transport.pendingBytes;
        f.client.call("waiting", "effect.once", {});
        verify(f.transport.pendingBytes > acceptedBytes);
        tryCompare(f.client, "unsent", [{id: "waiting", message: "UNSENT: socket admission waiting deadline exceeded", route: null}]);
        compare(f.transport.pendingBytes, acceptedBytes);
        compare(f.transport.pendingCalls, 1);
        compare(f.client.failures, 0);
        reply(f.transport, "accepted", {ok: true}, null);
        compare(f.transport.endpoint.writes.length, 1, "expiry cannot dispatch or replay the queued effect");
    }
    function test_duplicateAndLateRepliesCannotFreeReusedIdOrQueuedWork() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.client.call("same", "first", {});
        const oldWire = wireId(f.transport, "same");
        reply(f.transport, "same", {ok: true}, null);
        f.client.call("same", "second", {});
        f.client.call("queued", "third", {});
        const newWire = wireId(f.transport, "same");
        verify(oldWire !== newWire);
        f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: oldWire, ok: true, response: {ok: true}}));
        f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: wireId(f.transport, "queued"), ok: true, response: {ok: true}}));
        compare(f.client.replies.length, 1);
        compare(f.transport.pendingCalls, 1);
        compare(f.transport.queue.length, 1);
        reply(f.transport, "same", {ok: true}, null);
        compare(f.transport.queue.length, 0);
        compare(f.transport.pendingCalls, 1);
    }
    function test_unknownOutcomeKeepsNativePermitAndBoundsWaitingWithoutReplay() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.queueTimeout = 10;
        f.client.call("uncertain", "effect.once", {});
        const unknown = JSON.stringify({kind: "response", id: wireId(f.transport, "uncertain"), ok: false,
            outcome: "outcome-unknown", error: "reply unavailable"});
        f.transport.endpoint.deliver(unknown);
        compare(f.client.replies.length, 1);
        compare(f.transport.pendingCalls, 1, "unknown is not a native completion receipt");
        f.transport.endpoint.deliver(unknown);
        compare(f.client.replies.length, 1);
        f.client.call("waiting", "effect.once", {});
        tryCompare(f.client, "unsent", [{id: "waiting", message: "UNSENT: socket admission waiting deadline exceeded", route: null}]);
        compare(f.transport.endpoint.writes.length, 1);
        compare(f.client.failures, 0);
    }
    function test_releaseWithdrawsOnlyQueuedConsumerAndRetirementDoesNotReplay() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.client.call("accepted", "effect.once", {});
        const a = {consumerId: "a", localId: "waiting", kind: "call", generation: 3};
        const b = {consumerId: "b", localId: "waiting", kind: "call", generation: 3};
        f.client.call("a-wait", "effect.once", {}, a);
        f.client.call("b-wait", "effect.once", {}, b);
        f.client.release("release-a", {consumerId: "a", localId: "release", kind: "control", generation: 3});
        compare(f.client.unsent.length, 1);
        compare(f.client.unsent[0].id, "a-wait");
        compare(f.transport.queue.length, 1);
        compare(f.transport.pendingCalls, 1);
        compare(f.transport.pendingControls, 1);
        f.client.recover("retire owned fixture");
        compare(f.client.unsent.length, 2);
        compare(f.client.unsent[1].id, "b-wait");
        compare(f.transport.pendingBytes, 0);
        compare(f.transport.queue.length, 0);
    }
    function test_wrongRouteAndMalformedSuccessNeverGrantCredit() {
        for (const malformed of [false, true]) {
            const f = fixture();
            f.transport.maximumCalls = 1;
            const route = {consumerId: "a", localId: "read", kind: "call", generation: 2};
            f.client.call("read", "state.get", {}, route);
            f.client.call("queued", "effect.once", {});
            const socket = f.transport.endpoint;
            socket.deliver(JSON.stringify({kind: "response", id: wireId(f.transport, "read"), ok: true,
                route: Object.assign({}, route, {generation: malformed ? 2 : 1}), response: malformed ? null : {ok: true}}));
            verify(!f.transport.running);
            compare(f.client.replies.length, 0);
            compare(f.client.unsent.length, 1);
            tryCompare(f.client, "failures", 1);
        }
    }
    function test_wireIdentityNeverWrapsOrAliasesAtIntegerExhaustion() {
        const f = fixture();
        f.transport.sequence = Number.MAX_SAFE_INTEGER - 1;
        f.client.call("last", "state.get", {});
        const last = wireId(f.transport, "last");
        verify(last.endsWith(String(Number.MAX_SAFE_INTEGER)));
        let rejected = false;
        try { f.client.call("wrapped", "effect.once", {}); } catch (error) { rejected = String(error).includes("UNSENT"); }
        verify(rejected);
        compare(f.transport.endpoint.writes.length, 1);
        compare(f.transport.pendingCalls, 1);
        compare(f.client.failures, 0);
    }
    function test_expiredQueueCannotDispatchBeforeDelayedTimerDelivery() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.queueTimeout = 10;
        f.client.call("held", "state.get", {});
        f.client.call("expired", "effect.once", {});
        // Keep Qt's timer callback pending while an acknowledgement arrives in
        // this same event turn. Capacity is not authority to send expired work.
        const start = Date.now();
        while (Date.now() - start < 25) {}
        reply(f.transport, "held", {ok: true}, null);
        compare(f.transport.endpoint.writes.length, 1, "overdue timer delivery must not dispatch the expired effect");
        compare(f.client.unsent.length, 1);
        compare(f.client.unsent[0].id, "expired");
        compare(f.transport.pendingBytes, 0);
        compare(f.client.failures, 0);
    }
    function test_fullControlsReserveCleanupWithoutRaisingNativeCeiling() {
        const f = fixture();
        f.transport.queueTimeout = 60000;
        for (let i = 0; i < 15; i++) f.client.cancel("hold-" + i, "owned-" + i);
        f.client.cancel("cleanup", "exact-resource", null, true);
        compare(f.transport.pendingControls, 16);
        for (let i = 0; i < 15; i++) f.client.cancel("wait-" + i, "owned-wait-" + i);
        let rejected = false;
        try { f.client.cancel("overflow", "owned-overflow"); } catch (error) { rejected = String(error).includes("UNSENT"); }
        verify(rejected);
        f.client.cancel("queued-cleanup", "exact-late-resource", null, true);
        compare(f.transport.queue.length, 16, "last existing queue entry is reserved for cleanup");
        for (const wireId of f.transport.queue) {
            const record = f.transport.pending[wireId];
            record.expiresAt = Date.now() - 1;
            record.timer.interval = 1;
            record.timer.restart();
        }
        tryVerify(() => f.client.unsent.length === 16);
        compare(f.transport.pendingControls, 16, "queued expiry never releases native permits");
        compare(f.transport.endpoint.writes.length, 16);
        compare(f.transport.maximumControls, 16);
        compare(f.transport.maximumQueuedControls, 16);
        compare(f.client.failures, 0);
    }
    function test_controlBytesReserveExactResourceCleanupInsideExistingBudget() {
        const f = fixture();
        f.client.cancel("ordinary", "x".repeat(10000));
        const ordinaryBytes = f.transport.pendingControlBytes;
        verify(ordinaryBytes > 24 * 1024);
        let rejected = false;
        try { f.client.cancel("ordinary-overflow", "y".repeat(5000)); } catch (error) { rejected = String(error).includes("UNSENT"); }
        verify(rejected, "ordinary controls cannot spend cleanup byte reservation");
        f.client.cancel("cleanup", "\u0000".repeat(1024), {consumerId: "view", localId: "cleanup", kind: "control", generation: 0}, true);
        verify(f.transport.pendingControlBytes > ordinaryBytes);
        verify(f.transport.pendingControlBytes <= 64 * 1024);
        compare(f.transport.endpoint.writes.length, 2);
        compare(f.client.failures, 0);
    }
    function test_lateResourceReceiptsCannotReleaseUncertainNativeCredit() {
        for (const cleanup of [false, true]) {
            const f = fixture();
            const route = {consumerId: "view", localId: "resource", kind: cleanup ? "control" : "subscription", generation: 0};
            if (cleanup) f.client.cancel("resource", "exact-resource", route, true);
            else f.client.subscribeExtra("resource", ["state.changed"], route);
            const wire = wireId(f.transport, "resource");
            f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: wire, ok: false, outcome: "outcome-unknown", error: "unknown", route: route}));
            const bytes = f.transport.pendingBytes;
            const response = cleanup ? {ok: true, data: {cancelled: "exact-resource"}} : {ok: true, data: {subscription: {id: "late-native"}}};
            f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: wire, ok: true, response: response, route: route}));
            compare(f.client.replies.length, 2, "late receipt is delivered only to reconcile captured resource");
            compare(f.transport.pendingBytes, bytes);
            compare(f.transport.pending[wire].uncertain, true);
            compare(cleanup ? f.transport.pendingControls : f.transport.pendingCalls, 1);
            f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: wire, ok: true, response: response, route: route}));
            compare(f.client.replies.length, 2, "duplicate late receipt cannot regain authority");
            f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: wire, ok: true, response: response, route: Object.assign({}, route, {consumerId: "foreign"})}));
            compare(f.client.replies.length, 2); compare(f.client.failures, 0, "an ineligible duplicate is ignored before route validation");
            compare(f.transport.pendingBytes, bytes);
        }
    }
    function test_controlByteBudgetIsBoundedSeparately() {
        const f = fixture();
        f.transport.maximumPendingControlBytes = 1;
        let rejected = false;
        try { f.client.cancel("cancel", "operation"); } catch (error) { rejected = true; }
        verify(rejected);
        compare(f.transport.pendingControlBytes, 0);
        compare(f.transport.endpoint.writes.length, 0);
        f.client.call("read", "bluetooth.snapshot", {});
        compare(f.transport.pendingCalls, 1);
    }
    function test_malformedCorrelationCannotReleaseCreditAndKeepSocketOpen() {
        const ids = [["effect"], {}, null, 1, ""];
        for (const id of ids) {
            const f = fixture();
            f.client.recoverProtocolErrors = false;
            f.client.call("effect", "effect.once", {});
            f.transport.endpoint.deliver(JSON.stringify({kind: "response", id: id, ok: true, response: {ok: true}}));
            verify(!f.transport.running);
            tryCompare(f.client, "failures", 1);
        }
    }
    function test_byteBudgetMalformedReplyAndDeadlineFailClosed() {
        const f = fixture();
        f.transport.maximumPendingBytes = 8;
        let rejected = false;
        try { f.client.call("oversize", "effect.once", {}); } catch (error) { rejected = true; }
        verify(rejected);
        compare(f.transport.endpoint.writes.length, 0);
        f.transport.endpoint.deliver("null");
        tryCompare(f.client, "failures", 1);
        compare(f.client.ready, false);
        const timed = fixture();
        timed.transport.acknowledgementTimeout = 10;
        timed.client.call("missing", "effect.once", {});
        tryCompare(timed.client, "failures", 1);
        compare(timed.transport.pendingBytes, 0);
        verify(timed.transport.errorText.indexOf("outcome unknown") >= 0);
    }
}
