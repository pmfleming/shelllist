pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io

ShellRoot {
    id: root
    readonly property bool privateProbe: Quickshell.env("SHELLLIST_PRIVATE_CLIP_PROBE") === "1"
    readonly property bool controlProbe: Quickshell.env("SHELLLIST_CLIP_PROCESS_PHASE") === "control"
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
        active: root.privateProbe && !root.controlProbe
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
        active: root.privateProbe && !root.controlProbe
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
    Timer { interval: 20; repeat: true; running: root.privateProbe && !root.controlProbe; onTriggered: root.progress() }
    Timer { interval: 60000; running: root.privateProbe; onTriggered: root.fail("deadline phase=" + root.phase + " reads=" + root.reads) }
    Loader {
        active: root.privateProbe && root.controlProbe
        sourceComponent: Item {
            id: cleanupProbe
            property int step: 0
            property int unsent: 0
            property string knownExtra: ""
            property string lateExtra: ""
            property string oldBase: ""
            property string peerBase: ""
            property string detachedConsumer: ""
            function check(value: bool, message: string): void { if (!value) root.fail(message); }
            function tick(): void {
                const session = Io.DaemonSessions.sessions["clip-daemon"];
                const transport = session?.client.transportBackend;
                if (!session || !firstControl.ready || !controlPeer.ready) return;
                const main = session.consumers[firstControl.sharedConsumerId];
                const peer = session.consumers[controlPeer.sharedConsumerId];
                const records = Object.values(session.resources);
                check(session.generation === 0 && records.length <= 256, "pressure retired owner or exceeded bookkeeping");
                if (step === 0) {
                    if (!main.baseSubscriptionId || !peer.baseSubscriptionId || !detachedView.item?.ready) return;
                    oldBase = main.baseSubscriptionId;
                    peerBase = peer.baseSubscriptionId;
                    detachedConsumer = detachedView.item.sharedConsumerId;
                    knownExtra = firstControl.subscribeStreams(["clipboard.history.changed"]);
                    check(!!knownExtra, "known extra admission failed");
                    step = 1;
                } else if (step === 1) {
                    if (!firstControl.extraSubscriptions[knownExtra]) return;
                    lateExtra = firstControl.subscribeStreams(["clipboard.current.changed"]);
                    check(!!lateExtra && firstControl.unsubscribeStreams(lateExtra), "late extra cleanup intent failed");
                    detachedView.active = false; // native resource exists, reply is still gated
                    transport.queueTimeout = 300;
                    for (let i = 0; i < 15; i++)
                        check(firstControl.cancelWithId("hold-control-" + i, "cancel-held-control-" + i), "held control rejected");
                    check(firstControl.renewBaseSubscription(), "renewal failed under full admission");
                    check(transport.pendingControls === 16, "reserved cleanup did not fill native control window");
                    check(firstControl.unsubscribeStreams(knownExtra), "known extra release lost intent");
                    for (let i = 0; i < 15; i++)
                        check(firstControl.cancelWithId("never-control-" + i, "cancel-queued-control-" + i), "bounded control queue rejected early");
                    check(!firstControl.cancelWithId("overflow-control", "cancel-overflow-control"), "control overflow admitted");
                    step = 2;
                } else if (step === 2 && unsent === 16 && transport.queue.length === 0) {
                    check(transport.pendingControls === 16, "expiry released dispatched native credit");
                    check(records.some(row => row.nativeId === oldBase && row.state === "sending"), "full-lane renewal lost exact resource");
                    check(!session.consumers[detachedConsumer] && records.filter(row => row.state === "pending").length === 2,
                        "detach or extra release lost late-registration responsibility");
                    check(firstControl.call("control-during", "clipboard.history.query", {}), "logical peer progress failed");
                    step = 3;
                    console.log("CLIP_CONTROL_READY native16-overflow15-expired-no-credit-release");
                } else if (step === 3 && records.filter(row => !row.wanted && row.nativeId).length === 4) {
                    check(!firstControl.extraSubscriptions[lateExtra] && !session.consumers[detachedConsumer], "late ack revived view authority");
                    check(transport.pendingControls === 16, "native gate did not retain control permits");
                    step = 4;
                    console.log("CLIP_CONTROL_LATE_CAPTURED exact-native-resources-only");
                } else if (step === 4 && records.every(row => row.wanted) && transport.pendingControls === 0) {
                    check(main.baseSubscriptionId && main.baseSubscriptionId !== oldBase && peer.baseSubscriptionId === peerBase,
                        "cleanup replaced healthy logical peer or lost renewed base");
                    check(firstControl.pendingCount === 0 && Object.keys(firstControl.extraSubscriptions).length === 0, "late extra pending window leaked");
                    step = 5;
                    check(controlPeer.call("control-after", "clipboard.history.query", {}), "healthy peer stopped");
                }
            }
            Io.DaemonBackend {
                id: firstControl
                daemonName: "clip-daemon"; active: true; streams: ["clipboard.history.changed"]
                expectedProtocol: "clip-api"; expectedVersion: 2
                onTransportFailed: message => root.fail("control owner retired: " + message)
                onSendFailed: function(id, message) {
                    cleanupProbe.check(message.includes("UNSENT") && (id.startsWith("cancel-queued-control-") || id === "cancel-overflow-control"), "unexpected failure " + id);
                    cleanupProbe.unsent++;
                }
                onResponseReceived: function(id, envelope, error) {
                    cleanupProbe.check(id === "control-during" && !error && envelope?.ok, "logical read failed");
                }
            }
            Io.DaemonBackend {
                id: controlPeer
                daemonName: "clip-daemon"; active: true; streams: ["clipboard.history.changed"]
                expectedProtocol: "clip-api"; expectedVersion: 2
                onTransportFailed: message => root.fail("healthy logical control peer retired: " + message)
                onResponseReceived: function(id, envelope, error) {
                    cleanupProbe.check(id === "control-after" && !error && envelope?.ok && cleanupProbe.unsent === 16, "final healthy read failed");
                    console.log("CLIP_CONTROL_PASS exact-four-resources-one-owner-healthy-logical-native-peers-no-replay");
                    Qt.quit();
                }
            }
            Loader {
                id: detachedView
                active: true
                sourceComponent: Io.DaemonBackend {
                    daemonName: "clip-daemon"; active: true; streams: ["clipboard.current.changed"]
                    expectedProtocol: "clip-api"; expectedVersion: 2
                    onTransportFailed: message => root.fail("pending view owner retired: " + message)
                }
            }
            Timer { interval: 10; repeat: true; running: true; onTriggered: cleanupProbe.tick() }
        }
    }
    Component.onCompleted: { if (!privateProbe) fail("private producer harness required"); }
}
