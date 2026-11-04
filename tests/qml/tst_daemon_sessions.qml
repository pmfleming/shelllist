import QtQuick
import Shelllist.Io as Io

DaemonTestCase {
    id: tests
    name: "DaemonSessions"
    when: windowShown

    Component {
        id: backendFactory
        Io.DaemonBackend {
            daemonName: "stress-daemon"
            active: true
            property bool refreshOnReady: true
            onTransportReady: if (refreshOnReady) callSequenced("snapshot", "state.get", {})
        }
    }

    function test_attachToReadySession() {
        const peer = createTemporaryObject(backendFactory, tests, {refreshOnReady: false});
        verify(peer !== null && peer.ready);
        const session = Io.DaemonSessions.sessions[peer.daemonName];
        calls = [];
        const backend = createTemporaryObject(backendFactory, tests);
        verify(backend !== null && backend.ready);
        compare(Io.DaemonSessions.sessions[backend.daemonName], session);
        compare(calls.length, 1, "startup must run once, after attachment");
        compare(calls[0].route.consumerId, backend.sharedConsumerId);
        verify(backend.sharedConsumerId.length > 0, "never send an empty bridge route");
        peer.destroy();
        wait(0);
        compare(Object.keys(session.consumers).length, 1, "destroying the peer preserves the attached backend");
        clientReady = false;
        clientReady = true;
        compare(calls.length, 2, "reconnect still refreshes the attached backend");
        compare(calls[1].route.consumerId, backend.sharedConsumerId);
    }
}
