pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io

ShellRoot {
    id: root
    readonly property bool privateProbe: Quickshell.env("SHELLLIST_PRIVATE_CLIP_PROBE") === "1"
    readonly property int largeCharacters: Number(Quickshell.env("SHELLLIST_CLIP_PROBE_LARGE_CHARACTERS") || "0")
    property bool largeSent: false
    property bool largeSeen: false
    property int reads: 0
    property int discarded: 0
    property int phase: 0
    property int entries: -1
    property string mainSubscription: ""
    property string peerSubscription: ""
    property var sharedClient: null
    function fail(message) { console.error("CLIP_SOCKET_PROBE_FAIL " + message); Qt.exit(1); }
    function readMain() {
        if (!primary.item || primary.item.isPending("read")) return;
        const params = {fuzzy: root.largeCharacters === 0, limit: 200};
        if (largeCharacters && !largeSent) {
            // Ignored read-only fixture input exercises worst-case JSON escaping
            // for the default 16 MiB clipboard payload without publishing it.
            params.probe_padding = "\u0000".repeat(16 * 1024 * 1024);
            largeSent = true;
        }
        primary.item.call("read", "clipboard.history.query", params);
    }
    function progress() {
        const session = Io.DaemonSessions.sessions["clip-daemon"];
        if (!session || !peer.sharedConsumerId) return;
        const observer = session.consumers[peer.sharedConsumerId];
        if (!observer?.baseSubscriptionId) return;
        if (phase === 0) {
            const main = primary.item;
            if (!main || reads < 8 || entries !== 0 || main.requestPolicy.historyRevision < 2 || (largeCharacters && !largeSeen)) return;
            const subscription = session.consumers[main.sharedConsumerId]?.baseSubscriptionId;
            if (!subscription || !peer.requestPolicy.historyEpoch) return;
            if (!session.client.useSocket || !session.client.transportBackend.endpoint.connected
                    || Object.keys(session.consumers).length !== 2 || Object.keys(Io.DaemonSessions.sessions).length !== 1) {
                fail("not one shared native connection"); return;
            }
            mainSubscription = subscription;
            peerSubscription = observer.baseSubscriptionId;
            sharedClient = session.client;
            phase = 1;
            if (!main.renewBaseSubscription()) fail("renewal rejected");
        } else if (phase === 1) {
            const subscription = session.consumers[primary.item.sharedConsumerId]?.baseSubscriptionId;
            if (!subscription || subscription === mainSubscription) return;
            if (observer.baseSubscriptionId !== peerSubscription) { fail("renewal replaced peer subscription"); return; }
            phase = 2;
            primary.active = false;
        } else if (phase === 2) {
            if (Object.keys(session.consumers).length !== 1) return;
            if (session.client !== sharedClient || observer.baseSubscriptionId !== peerSubscription) { fail("peer connection was replaced"); return; }
            phase = 3;
            peer.call("peer-final", "clipboard.history.query", {fuzzy: true});
        }
    }
    Loader {
        id: primary
        active: root.privateProbe
        sourceComponent: Io.DaemonBackend {
            id: mainBackend
            daemonName: "clip-daemon"
            expectedProtocol: "clip-api"
            expectedVersion: 2
            streams: ["clipboard.history.changed", "clipboard.current.changed"]
            active: true
            requestPolicy: Io.ClipboardStateRecovery {
                backend: mainBackend
                onHistoryInvalidated: { if (root.phase === 0) root.readMain(); }
                onReadDiscarded: function(id) { root.discarded++; if (root.phase === 0) root.readMain(); }
            }
            onResponseReceived: function(id, envelope, error) {
                if (id !== "read" || error || !envelope?.ok || !Array.isArray(envelope.data?.history?.entries)) { root.fail("invalid history read"); return; }
                if (root.largeCharacters && root.reads === 0) {
                    const preview = envelope.data.history.entries[0]?.preview;
                    if (typeof preview !== "string" || preview.length !== root.largeCharacters
                            || !preview.startsWith("🦀") || !preview.endsWith("🦀")) { root.fail("large UTF-8 response damaged"); return; }
                    root.largeSeen = true;
                }
                root.reads++;
                root.entries = envelope.data.history.entries.length;
                if (root.phase === 0 && (root.reads < 8 || root.entries !== 0)) root.readMain();
                root.progress();
            }
            onTransportFailed: function(message) { root.fail(message); }
            onSendFailed: function(id, message) { root.fail(id + ": " + message); }
        }
    }
    Io.DaemonBackend {
        id: peer
        daemonName: "clip-daemon"
        expectedProtocol: "clip-api"
        expectedVersion: 2
        streams: ["clipboard.history.changed"]
        active: root.privateProbe
        requestPolicy: Io.ClipboardStateRecovery {
            backend: peer
            onReadDiscarded: function(id) { if (root.phase === 3) peer.call("peer-final", "clipboard.history.query", {fuzzy: true}); }
        }
        onResponseReceived: function(id, envelope, error) {
            if (root.phase !== 3 || id !== "peer-final" || error || !envelope?.ok
                    || envelope.data?.history?.entries?.length !== 0 || requestPolicy.historyRevision < 2) { root.fail("surviving peer read invalid"); return; }
            root.phase = 4;
            console.log("CLIP_SOCKET_PROBE_PASS reads-invalidation-renewal-peer-release discarded=" + root.discarded + " large=" + root.largeSeen);
            Qt.quit();
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Timer { interval: 20; repeat: true; running: root.privateProbe; onTriggered: root.progress() }
    Timer { interval: 60000; running: root.privateProbe; onTriggered: root.fail("deadline phase=" + root.phase + " reads=" + root.reads) }
    Component.onCompleted: { if (!privateProbe) fail("private producer harness required"); }
}
