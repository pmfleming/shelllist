pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// Process-shaped lifecycle adapter only. Routing and domain policy remain in
// JsonlDaemonClient/DaemonSessions. Each generation owns a fresh native Socket.
QtObject {
    id: transport
    required property string socketPath
    property bool running: false
    property bool stdinEnabled: true
    property string errorText: ""
    property var endpoint: null
    property var pending: Object.create(null)
    property int pendingBytes: 0
    property int pendingControlBytes: 0
    property int pendingCalls: 0
    property int pendingControls: 0
    property int maximumPendingBytes: 4 * 1024 * 1024
    property int maximumPendingControlBytes: 64 * 1024
    property int maximumCalls: 64
    property int maximumControls: 16
    property int acknowledgementTimeout: 35000
    property bool stopping: false
    property int generation: 0
    readonly property string shutdownId: "__shelllist_socket_shutdown__"

    signal started()
    signal exited(int exitCode)
    signal messageReceived(var message)

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

    function forget(id) {
        const record = pending[id];
        if (!record)
            return;
        record.timer.stop();
        record.timer.destroy();
        pendingBytes -= record.bytes;
        if (record.control) {
            pendingControlBytes -= record.bytes;
            pendingControls--;
        } else {
            pendingCalls--;
        }
        delete pending[id];
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
        for (const id of Object.keys(pending))
            forget(id);
        pending = Object.create(null);
        if (previous) {
            previous.connected = false;
            // disconnectFromServer may wait for writes. Destruction ensures a
            // non-reading peer cannot retain this generation's buffered effects.
            previous.destroy();
        }
        const retired = generation;
        // Match asynchronous Process exit: recover() must establish its backoff
        // before an exit can wake a replacement transport.
        Qt.callLater(function() {
            if (transport.generation === retired && !transport.running)
                transport.exited(code);
        });
    }

    function write(line) {
        if (!running || stopping || !endpoint || !endpoint.connected)
            throw new Error("socket is not accepting requests; request was not sent");
        const message = JSON.parse(line);
        if (!message.id || message.id === shutdownId || pending[message.id])
            throw new Error("invalid or duplicate pending request id; request was not sent");
        const control = message.op === "subscribe" || message.op === "cancel" || message.op === "release";
        // UTF-8 needs at most three bytes per UTF-16 code unit. Reserving until
        // acknowledgement bounds Qt's otherwise opaque write buffer, including
        // bytes already in the kernel. No partial-write guessing or replay.
        const bytes = line.length * 3;
        const laneBytes = control ? pendingControlBytes : pendingBytes - pendingControlBytes;
        const laneLimit = control ? maximumPendingControlBytes : maximumPendingBytes;
        if (laneBytes + bytes > laneLimit
                || (control ? pendingControls >= maximumControls : pendingCalls >= maximumCalls))
            throw new Error("socket request capacity exceeded; request was not sent");
        const timer = requestDeadline.createObject(transport) as Timer;
        pending[message.id] = {bytes: bytes, control: control, timer: timer};
        pendingBytes += bytes;
        if (control) {
            pendingControlBytes += bytes;
            pendingControls++;
        } else {
            pendingCalls++;
        }
        timer.start();
        endpoint.write(line);
    }

    function receive(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            finish(1, "Invalid socket JSON: " + error);
            return;
        }
        if (!message || typeof message !== "object" || Array.isArray(message)) {
            finish(1, "Invalid socket record");
            return;
        }
        if (message.kind === "response") {
            if (typeof message.id !== "string" || !message.id || typeof message.ok !== "boolean") {
                finish(1, "Invalid socket response correlation");
                return;
            }
            if (stopping && message.id === shutdownId && message.ok && message.response && message.response.shutdown) {
                finish(0, "");
                return;
            }
            forget(message.id);
        }
        messageReceived(message);
    }

    function abort(message) {
        finish(1, message || "Socket generation retired");
    }

    function requestStop() {
        if (!running || stopping)
            return;
        stopping = true;
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
            interval: transport.acknowledgementTimeout
            onTriggered: transport.finish(1, "Socket acknowledgement deadline exceeded; outcome unknown; do not replay")
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
