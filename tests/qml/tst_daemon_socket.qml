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
            for (const enabled of ["", "SHELLLIST_NM_SOCKET", "SHELLLIST_BT_SOCKET", "SHELLLIST_APP_SOCKET", "SHELLLIST_BAR_SOCKET", "SHELLLIST_CLIP_SOCKET"]) {
                QuickshellFixture.Quickshell.environment = Object.assign({XDG_RUNTIME_DIR: "/isolated"}, enabled ? {[enabled]: "1"} : {});
                for (const daemon of ["nm-daemon", "bt-daemon", "app-daemon", "bar-daemon", "clip-daemon"]) {
                    const client = createTemporaryObject(optInFactory, testCase, {daemonName: daemon}) as Io.JsonlDaemonClient;
                    verify(client !== null);
                    compare(client.useSocket, (daemon === "nm-daemon" && enabled === "SHELLLIST_NM_SOCKET")
                        || (daemon === "bt-daemon" && enabled === "SHELLLIST_BT_SOCKET")
                        || (daemon === "app-daemon" && enabled === "SHELLLIST_APP_SOCKET")
                        || (daemon === "bar-daemon" && enabled === "SHELLLIST_BAR_SOCKET")
                        || (daemon === "clip-daemon" && enabled === "SHELLLIST_CLIP_SOCKET"));
                    compare(client.socketPath, "/isolated/" + daemon + ".sock");
                    const transport = findChild(client, "daemonSocketTransport");
                    compare(transport.maximumPendingBytes, daemon === "clip-daemon" ? 3 * (128 * 1024 * 1024 + 1) : 4 * 1024 * 1024);
                    compare(transport.maximumCalls, daemon === "clip-daemon" ? 4 : 64);
                }
            }
        } finally {
            QuickshellFixture.Quickshell.environment = original;
        }
    }
    function test_clipboardOptInRequiresExactOne() {
        const original = QuickshellFixture.Quickshell.environment;
        try {
            for (const value of ["", "0", "true", "1"]) {
                QuickshellFixture.Quickshell.environment = {XDG_RUNTIME_DIR: "/isolated", SHELLLIST_CLIP_SOCKET: value};
                const client = createTemporaryObject(optInFactory, testCase, {daemonName: "clip-daemon"}) as Io.JsonlDaemonClient;
                verify(client !== null);
                compare(client.useSocket, value === "1");
            }
        } finally { QuickshellFixture.Quickshell.environment = original; }
    }
    function test_barOptInRequiresExactOne() {
        const original = QuickshellFixture.Quickshell.environment;
        try {
            for (const value of ["", "0", "true", "1"]) {
                QuickshellFixture.Quickshell.environment = {XDG_RUNTIME_DIR: "/isolated", SHELLLIST_BAR_SOCKET: value};
                const client = createTemporaryObject(optInFactory, testCase, {daemonName: "bar-daemon"}) as Io.JsonlDaemonClient;
                verify(client !== null);
                compare(client.useSocket, value === "1");
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
    function reply(socket, id, response, route) {
        socket.deliver(JSON.stringify({kind: "response", id: id, ok: true, response: response, route: route}));
    }
    function test_responseAndRoutePreserveWireAndReleaseWindow() {
        const f = fixture();
        const route = {consumerId: "view", localId: "read", generation: 4, kind: "call"};
        f.client.call("read", "bluetooth.snapshot", {}, route);
        const message = JSON.parse(f.transport.endpoint.writes[0]);
        compare(message.route, route);
        compare(f.transport.pendingCalls, 1);
        reply(f.transport.endpoint, "read", {ok: true}, route);
        compare(f.client.replies.length, 1);
        compare(f.client.replies[0].route, route);
        compare(f.transport.pendingCalls, 0);
        compare(f.transport.pendingBytes, 0);
    }
    function test_backpressureReservesControlsAndNeverReplaysFailedEffects() {
        const f = fixture();
        f.transport.maximumCalls = 1;
        f.transport.maximumControls = 1;
        f.client.call("effect", "effect.once", {});
        f.transport.maximumPendingBytes = f.transport.pendingBytes;
        let rejected = false;
        try { f.client.call("overflow", "effect.once", {}); } catch (error) { rejected = true; }
        verify(rejected);
        f.client.cancel("cancel", "owned-operation");
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
    function test_closeDrainsRepliesAndReopenQueuesForFreshGeneration() {
        const f = fixture();
        f.client.call("old", "effect.once", {});
        const old = f.transport.endpoint;
        f.client.active = false;
        compare(f.client.lifecycle, "stopping");
        compare(JSON.parse(old.writes[1]).op, "shutdown");
        f.client.active = true;
        f.client.call("new", "effect.once", {});
        compare(old.writes.length, 2);
        reply(old, "old", {ok: true}, null);
        compare(f.client.replies.length, 1);
        reply(old, f.transport.shutdownId, {shutdown: true}, null);
        tryCompare(f.client, "ready", true);
        compare(f.client.failures, 0);
        compare(f.transport.endpoint.writes.length, 1);
        compare(JSON.parse(f.transport.endpoint.writes[0]).id, "new");
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
