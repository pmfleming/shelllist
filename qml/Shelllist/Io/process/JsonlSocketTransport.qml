pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../JsonlRouting.js" as Routing

// One bounded admission window per socket owner, shared by every logical view.
// Native RequestSlots charges Call AND Subscribe to calls; cleanup is separate.
QtObject {
    id: transport
    required property string socketPath
    property bool running: false
    property bool stdinEnabled: true
    property string errorText: ""
    property var endpoint: null
    property var pending: Object.create(null)
    property var queue: []
    property int pendingBytes: 0 // reservations include queued, never-written records
    property int pendingControlBytes: 0
    property int pendingCalls: 0 // dispatched records only
    property int pendingControls: 0
    property int maximumPendingBytes: 4 * 1024 * 1024
    property int maximumPendingControlBytes: 64 * 1024
    readonly property int reservedCleanupBytes: 24 * 1024
    property int maximumCalls: 64
    property int maximumControls: 16
    property int maximumQueuedRequests: 256
    property int maximumQueuedControls: 16
    property int queueTimeout: 5000
    property int acknowledgementTimeout: 35000
    property bool stopping: false
    property bool pumping: false
    property int generation: 0
    property double sequence: 0
    readonly property string shutdownId: "__shelllist_socket_shutdown__"

    signal started()
    signal exited(int exitCode)
    signal messageReceived(var message)
    signal requestUnsent(string id, string message, var route)

    function exec(command) {
        if (running)
            throw new Error("socket transport is already running");
        if (!socketPath || socketPath[0] !== "/")
            throw new Error("an absolute runtime socket path is required");
        errorText = "";
        generation++;
        stopping = false;
        running = true;
        endpoint = socketFactory.createObject(transport, {path: socketPath});
        if (!endpoint) {
            running = false;
            throw new Error("could not construct Unix socket");
        }
        connectDeadline.start();
        endpoint.connected = true;
    }

    function forget(wireId) {
        const record = pending[wireId];
        if (!record)
            return;
        delete pending[wireId]; // retire identity before any notifying counters
        queue = queue.filter(id => id !== wireId);
        record.timer.stop();
        record.timer.destroy();
        pendingBytes -= record.bytes;
        if (record.control) {
            pendingControlBytes -= record.bytes;
            if (record.dispatched) pendingControls--;
        } else if (record.dispatched) {
            pendingCalls--;
        }
    }

    function rejectQueued(wireId, detail) {
        const record = pending[wireId];
        if (!record || record.dispatched)
            return;
        forget(wireId);
        requestUnsent(record.id, "UNSENT: " + detail, record.route);
    }

    function discardQueued(consumerId) {
        for (const wireId of queue.slice()) {
            const record = pending[wireId];
            if (record && !record.control && record.route?.consumerId === consumerId)
                rejectQueued(wireId, "consumer released before socket dispatch");
        }
    }

    function finish(code, detail) {
        if (!running)
            return;
        connectDeadline.stop();
        shutdownDeadline.stop();
        errorText = detail || "";
        running = false;
        const previous = endpoint;
        endpoint = null; // fence callbacks before closing/destroying the native object
        for (const wireId of Object.keys(pending)) {
            rejectQueued(wireId, "socket generation retired before dispatch");
            forget(wireId);
        }
        pending = Object.create(null);
        if (previous) {
            previous.connected = false;
            previous.destroy(); // discard Qt's opaque write buffer, never replay it
        }
        const retired = generation;
        Qt.callLater(function() {
            if (transport.generation === retired && !transport.running)
                transport.exited(code);
        });
    }

    function dispatchReady(control: bool, cleanup: bool): bool {
        return control ? pendingControls < (cleanup ? maximumControls : Math.max(0, maximumControls - 1))
            : pendingCalls < maximumCalls;
    }

    function write(line, reservedCleanup) {
        if (!running || stopping || !endpoint)
            throw new Error("UNSENT: socket is not accepting requests");
        const message = JSON.parse(line);
        if (!message.id || message.id === shutdownId || Object.values(pending).some(record => record.id === message.id && !record.uncertain))
            throw new Error("UNSENT: invalid or duplicate pending request id");
        if (!Number.isSafeInteger(sequence) || sequence >= Number.MAX_SAFE_INTEGER)
            throw new Error("UNSENT: socket wire identity space exhausted");
        const control = message.op === "cancel" || message.op === "release";
        if (message.op === "release")
            discardQueued(message.route?.consumerId);
        // A unique wire ID fences duplicate/late responses after local ID reuse.
        // Retain a serialized snapshot, not a caller-mutable params/route object.
        const id = message.id;
        const wireId = "__shelllist_wire_" + generation + "_" + (++sequence);
        message.id = wireId;
        const capturedLine = JSON.stringify(message) + "\n";
        const bytes = capturedLine.length * 3;
        const laneBytes = control ? pendingControlBytes : pendingBytes - pendingControlBytes;
        const laneLimit = control ? maximumPendingControlBytes : maximumPendingBytes;
        // One of the existing control slots/queue entries is reserved for the
        // session's captured resource transaction. No native ceiling is raised.
        const cleanup = control && !!reservedCleanup; // local admission hint, never a wire/route extension
        const queuedControlLimit = cleanup ? maximumQueuedControls : Math.max(0, maximumQueuedControls - 1);
        const waiting = queue.reduce((count, key) => count + (pending[key].control === control ? 1 : 0), 0);
        const ordinaryControlBytes = control && !cleanup ? Object.values(pending)
            .reduce((total, record) => total + (record.control && !record.cleanup ? record.bytes : 0), 0) : 0;
        if ((control && !cleanup && ordinaryControlBytes + bytes > Math.max(0, maximumPendingControlBytes - reservedCleanupBytes))
                || laneBytes + bytes > laneLimit || ((!dispatchReady(control, cleanup) || !endpoint.connected || waiting > 0)
                && waiting >= (control ? queuedControlLimit : maximumQueuedRequests)))
            throw new Error("UNSENT: socket admission queue or byte capacity exceeded");
        const timer = requestDeadline.createObject(transport, {wireId: wireId}) as Timer;
        pending[wireId] = {id: id, route: message.route || null, bytes: bytes, control: control,
            timer: timer, line: capturedLine, dispatched: false, uncertain: false, cleanup: cleanup,
            operation: message.op, lateResourceSeen: false,
            expiresAt: Date.now() + queueTimeout};
        pendingBytes += bytes;
        if (control) pendingControlBytes += bytes;
        queue = queue.concat([wireId]);
        timer.interval = queueTimeout;
        timer.start();
        pump();
    }

    function pump() {
        if (pumping || !running || stopping || !endpoint?.connected)
            return;
        pumping = true;
        try {
            // FIFO within each lane; a blocked data lane never blocks cleanup.
            for (const wireId of queue.slice()) {
                const record = pending[wireId];
                if (!record)
                    continue;
                // The timer callback may still be pending in this event turn.
                // Newly available credit cannot extend the captured waiting age.
                if (Date.now() >= record.expiresAt) {
                    rejectQueued(wireId, "socket admission waiting deadline exceeded");
                    continue;
                }
                if (!dispatchReady(record.control, record.cleanup))
                    continue;
                queue = queue.filter(id => id !== wireId);
                record.dispatched = true; // write may synchronously reenter receive
                if (record.control) pendingControls++; else pendingCalls++;
                record.timer.stop();
                record.timer.interval = acknowledgementTimeout;
                record.timer.start();
                const line = record.line;
                record.line = ""; // Qt now owns bytes; keep the reservation, not a copy
                try {
                    endpoint.write(line);
                } catch (error) {
                    finish(1, "Socket write failed; outcome unknown; do not replay");
                    break;
                }
                if (!running || stopping) break;
            }
        } finally {
            pumping = false;
        }
        // A synchronous response can enqueue a replacement during write().
        if (queue.some(id => dispatchReady(pending[id].control, pending[id].cleanup)))
            Qt.callLater(transport.pump);
    }

    function sameRoute(left, right) {
        if (!left || !right) return !left && !right;
        return left.consumerId === right.consumerId && left.localId === right.localId
            && left.kind === right.kind && left.generation === right.generation;
    }

    function receive(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            finish(1, "Invalid socket JSON");
            return;
        }
        if (!message || typeof message !== "object" || Array.isArray(message)) {
            finish(1, "Invalid socket record");
            return;
        }
        if (message.kind !== "response") {
            messageReceived(message);
            return;
        }
        if (typeof message.id !== "string" || !message.id || typeof message.ok !== "boolean") {
            finish(1, "Invalid socket response correlation");
            return;
        }
        if (stopping && message.id === shutdownId && message.ok && message.response?.shutdown) {
            finish(0, "");
            return;
        }
        const wireId = message.id;
        const record = pending[wireId];
        if (!record || !record.dispatched)
            return; // duplicate or never written; cannot grant credit/deliver
        // A late resource receipt can establish cleanup responsibility only.
        // It cannot release uncertain native credit or regain view authority.
        const lateResource = record.uncertain;
        if (lateResource && (record.lateResourceSeen || !message.ok
                || (record.operation !== "subscribe" && !record.cleanup)))
            return;
        if (!sameRoute(record.route, message.route || null) || !Routing.responsePayloadValid(message)) {
            finish(1, "Invalid socket response identity or outcome; outcome unknown");
            return;
        }
        message.id = record.id;
        // Timeout/error receipts do NOT prove the native retained work/permit
        // ended. Keep its credit and original deadline until owner retirement.
        if (lateResource)
            record.lateResourceSeen = true;
        else if (!message.ok && message.outcome === "outcome-unknown")
            record.uncertain = true;
        else
            forget(wireId);
        messageReceived(message); // captured identity retired before callbacks reuse IDs
        pump();
    }

    function abort(message) {
        finish(1, message || "Socket generation retired");
    }

    function requestStop() {
        if (!running || stopping)
            return;
        stopping = true;
        for (const wireId of queue.slice())
            rejectQueued(wireId, "socket stopped before dispatch");
        if (!endpoint || !endpoint.connected) {
            finish(0, "");
            return;
        }
        endpoint.write(JSON.stringify({op: "shutdown", id: shutdownId}) + "\n");
        shutdownDeadline.start();
    }
    onStdinEnabledChanged: if (!stdinEnabled) requestStop()

    property Component socketFactory: Component {
        Socket {
            id: nativeSocket
            objectName: "daemonNativeSocket"
            onConnectionStateChanged: {
                if (transport.endpoint !== nativeSocket)
                    return;
                if (connected) {
                    transport.connectDeadline.stop();
                    transport.started();
                    transport.pump();
                    if (!transport.stdinEnabled)
                        transport.requestStop();
                } else {
                    transport.finish(1, "Unix socket disconnected");
                }
            }
            onError: function(error) { // qmllint disable signal-handler-parameters
                if (transport.endpoint === nativeSocket)
                    transport.finish(1, "Unix socket error " + error);
            }
            parser: SplitParser {
                splitMarker: "\n"
                onRead: function(line) {
                    if (transport.endpoint === nativeSocket)
                        transport.receive(line);
                }
            }
        }
    }
    property Component requestDeadline: Component {
        Timer {
            required property string wireId
            onTriggered: {
                const record = transport.pending[wireId];
                if (record?.dispatched)
                    transport.finish(1, "Socket acknowledgement deadline exceeded; outcome unknown; do not replay");
                else
                    transport.rejectQueued(wireId, "socket admission waiting deadline exceeded");
            }
        }
    }
    property Timer connectDeadline: Timer {
        interval: 5000
        onTriggered: transport.finish(1, "Unix socket connection deadline exceeded")
    }
    property Timer shutdownDeadline: Timer {
        interval: transport.acknowledgementTimeout
        onTriggered: transport.finish(1, "Socket shutdown deadline exceeded; outcome unknown; do not replay")
    }
}
