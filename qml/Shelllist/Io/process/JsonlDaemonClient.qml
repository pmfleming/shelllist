import Quickshell
import Quickshell.Io
import QtQuick
import "../JsonlRouting.js" as Routing

Item {
    id: client

    required property string daemonName
    required property var streams
    required property bool active
    property bool ready
    property bool componentReady: false
    property bool automaticSubscribe: true
    required property bool recoverProtocolErrors
    property var queuedLines: []
    property int maximumQueuedRequests: 256
    property bool retiring: false
    // Staged opt-ins only. No automatic bridge fallback/replay on failure.
    property bool useSocket: (daemonName === "bt-daemon" && Quickshell.env("SHELLLIST_BT_SOCKET") === "1")
        || (daemonName === "nm-daemon" && Quickshell.env("SHELLLIST_NM_SOCKET") === "1")
        || (daemonName === "app-daemon" && Quickshell.env("SHELLLIST_APP_SOCKET") === "1")
        || (daemonName === "bar-daemon" && Quickshell.env("SHELLLIST_BAR_SOCKET") === "1")
        || (daemonName === "clip-daemon" && Quickshell.env("SHELLLIST_CLIP_SOCKET") === "1")
    property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/" + daemonName + ".sock" : ""
    readonly property var transportBackend: useSocket ? socketTransport : process
    // A frontend transport generation, never the resident daemon's lifetime.
    property string lifecycle: "stopped"
    property var counters: ({
            sequence: 0,
            retryAttempt: 0
        })
    property string subscriptionId: ""
    property int initialRetryInterval: 1500
    property int maximumRetryInterval: 30000

    signal response(string id, var envelope, string transportError, var route)
    signal eventReceived(var event, var route)
    signal transportFailed(string message)
    signal requestUnsent(string id, string message, var route)
    signal ownerRetired()

    function discardQueued(consumerId) {
        if (useSocket)
            socketTransport.discardQueued(consumerId);
    }

    function start() {
        if (!componentReady || !active || lifecycle !== "stopped" || transportBackend.running || retryTimer.running)
            return;
        lifecycle = "starting";
        transportBackend.stdinEnabled = true;
        try {
            console.info("shelllist transport starting daemon=" + daemonName);
            transportBackend.exec([daemonName, "client"]);
        } catch (error) {
            lifecycle = "stopped";
            transportBackend.stdinEnabled = false;
            // Requests belong to one transport generation. Once that
            // generation is reported failed they must never be replayed by a
            // later process, especially when they may carry an effect.
            clearQueue();
            const message = "Could not start " + daemonName + " client: " + error;
            console.error("shelllist transport failed daemon=" + daemonName + " stage=start error=" + error);
            transportFailed(message);
            ownerRetired(); // failed startup never acquired a usable physical owner
            scheduleRetry();
        }
    }

    function clearQueue() {
        queuedLines = [];
    }

    function stop(failureMessage) {
        retryTimer.stop();
        clearQueue();
        if (lifecycle === "stopped")
            return;
        lifecycle = "stopping";
        ready = false;
        subscriptionId = "";
        // EOF tells the Rust bridge to drain accepted calls and cancel its own
        // subscriptions/operations. Keep delivering those replies, but queue
        // new requests for a replacement rather than writing to closing stdin.
        // Only failed generations fence stdout in recover().
        if (useSocket && failureMessage)
            socketTransport.abort(failureMessage);
        else
            transportBackend.stdinEnabled = false;
    }

    function call(id, method, params, route) {
        send({
            id: id,
            op: "call",
            method: method,
            params: params || ({}),
            route: route
        });
    }
    function cancel(idOrRequestId, optionalRequestId, route, cleanup) {
        const requestId = optionalRequestId || idOrRequestId;
        if (!requestId)
            return;
        const id = optionalRequestId ? idOrRequestId : "cancel-" + (++counters.sequence);
        send({
            id: id,
            op: "cancel",
            request_id: requestId,
            route: route
        }, cleanup);
    }

    function release(id, route, cleanup) {
        send({
            id: id,
            op: "release",
            route: route
        }, cleanup);
    }

    function send(message, cleanup) {
        const line = JSON.stringify(message);
        if (useSocket) {
            // Socket admission owns connecting and ready queues in ONE bounded
            // owner generation. Never move an unsent effect across retirement.
            if (!ready)
                start();
            socketTransport.write(line + "\n", !!cleanup);
            return;
        }
        if (!ready) {
            if (queuedLines.length >= maximumQueuedRequests)
                throw new Error("UNSENT: bridge startup queue capacity exceeded; request was not sent");
            queuedLines = queuedLines.concat([line]);
            start();
            return;
        }
        transportBackend.write(line + "\n");
    }

    function flushQueue() {
        const lines = queuedLines;
        queuedLines = [];
        for (let index = 0; index < lines.length; index++)
            transportBackend.write(lines[index] + "\n");
    }

    function subscribe() {
        send({
            id: "session-subscribe",
            op: "subscribe",
            streams: streams
        });
    }

    // Adds a subscription beyond the session's default streams, for a view that
    // only wants a stream while it is open. The daemon computes those payloads
    // only while somebody is subscribed, so dropping it again matters.
    function subscribeExtra(id, extraStreams, route) {
        send({
            id: id,
            op: "subscribe",
            streams: extraStreams,
            route: route
        });
    }

    function rememberSubscription(message) {
        if (message.id === "session-subscribe" && message.ok)
            subscriptionId = Routing.subscriptionId(message);
    }
    function markHealthy() {
        counters.retryAttempt = 0;
    }
    function scheduleRetry() {
        if (!active)
            return;
        retryTimer.interval = Math.min(maximumRetryInterval, initialRetryInterval * Math.pow(2, counters.retryAttempt));
        counters.retryAttempt = Math.min(counters.retryAttempt + 1, 30);
        console.warn("shelllist transport retry scheduled daemon=" + daemonName + " delay_ms=" + retryTimer.interval + " attempt=" + counters.retryAttempt);
        retryTimer.restart();
    }
    function handleResponse(message) {
        if (typeof message.id !== "string" || !message.id || typeof message.ok !== "boolean"
                || !Routing.responsePayloadValid(message))
            throw new Error("Invalid daemon response correlation or payload");
        const outcome = Routing.responseOutcome(message, daemonName);
        if (outcome.recover) {
            console.error("shelllist transport subscription failed daemon=" + daemonName + " error=" + outcome.error);
            response(outcome.id, null, outcome.error, outcome.route);
            recover(outcome.error);
            return;
        }
        markHealthy();
        rememberSubscription(message);
        response(outcome.id, outcome.envelope, outcome.error, outcome.route);
    }
    function recover(message) {
        retiring = true;
        // Close dispatch before public failure callbacks can submit replacement
        // work. Resource retirement is signalled separately on actual exit.
        stop(message);
        try {
            transportFailed(message);
        } finally {
            ready = false;
            scheduleRetry();
        }
    }
    function handleMessage(message) {
        if (message.kind === "event") {
            markHealthy();
            eventReceived(message.event || ({}), message.route || null);
            return;
        }
        if (message.kind === "response") {
            handleResponse(message);
            return;
        }
        if (Routing.isFailureKind(message.kind)) {
            const detail = message.error || daemonName + " client failed";
            if (Routing.shouldRecoverFailure(message.kind, recoverProtocolErrors))
                recover(detail);
            else
                transportFailed(detail);
        }
    }
    function handleLine(line) {
        if (retiring)
            return;
        try {
            handleMessage(JSON.parse(line));
        } catch (error) {
            const message = "Could not parse " + daemonName + " output: " + error;
            if (recoverProtocolErrors)
                recover(message);
            else
                transportFailed(message);
        }
    }

    function transportStarted() {
        console.info("shelllist transport started daemon=" + daemonName + " socket=" + useSocket);
        if (lifecycle === "stopping") {
            transportBackend.stdinEnabled = false;
            return;
        }
        if (!active) {
            stop();
            return;
        }
        retiring = false;
        lifecycle = "running";
        ready = true;
        if (lifecycle !== "running")
            return;
        try {
            if (automaticSubscribe)
                subscribe();
            flushQueue();
        } catch (error) {
            recover("Could not initialize " + daemonName + " client: " + error);
        }
    }
    function transportExited(exitCode) {
        const expected = lifecycle === "stopping" && exitCode === 0 && !retiring;
        ready = false;
        lifecycle = "stopped";
        if (expected) {
            ownerRetired(); // graceful close also ends native identity/resource authority
            start();
            return;
        }
        clearQueue();
        if (retiring) {
            ownerRetired();
            start();
            return;
        }
        if (!active) {
            ownerRetired();
            return;
        }
        const stderr = useSocket ? socketTransport.errorText : processError.text;
        const detail = stderr.length > 0 ? stderr : "exit " + exitCode;
        console.error("shelllist transport exited daemon=" + daemonName + " detail=" + detail);
        transportFailed(daemonName + " client stopped: " + detail);
        ownerRetired();
        if (!retryTimer.running)
            scheduleRetry();
    }

    JsonlSocketTransport {
        id: socketTransport
        objectName: "daemonSocketTransport"
        socketPath: client.socketPath
        // Clipboard retains the bridge's 128 MiB escaped-record allowance.
        // The adapter reserves three bytes per UTF-16 unit until acknowledgement;
        // this is a bounded reservation budget, not a larger producer frame limit.
        maximumPendingBytes: client.daemonName === "clip-daemon" ? 3 * (128 * 1024 * 1024 + 1) : 4 * 1024 * 1024
        maximumCalls: client.daemonName === "clip-daemon" ? 4 : 64
        onStarted: client.transportStarted()
        onExited: function(exitCode) { client.transportExited(exitCode); }
        onRequestUnsent: function(id, message, route) { client.requestUnsent(id, message, route); }
        onMessageReceived: function(message) {
            if (client.retiring)
                return;
            try {
                client.handleMessage(message);
            } catch (error) {
                client.recover("Invalid " + client.daemonName + " socket message: " + error);
            }
        }
    }

    Component.onCompleted: {
        componentReady = true;
        start();
    }
    onActiveChanged: {
        if (active) {
            start();
        } else {
            stop();
            counters.retryAttempt = 0;
        }
    }

    Process {
        id: process
        objectName: "daemonBridgeProcess"
        stdinEnabled: true
        // Tokio's default multi-thread runtime otherwise creates one worker per
        // logical CPU for each lightweight JSONL-to-D-Bus bridge process. QML's
        // object literal reaches Process's QVariantHash correctly at runtime.
        // qmllint disable incompatible-type
        environment: ({
                TOKIO_WORKER_THREADS: "1"
            })
        // qmllint enable incompatible-type
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                client.handleLine(line);
            }
        }
        stderr: StdioCollector {
            id: processError
            waitForEnd: true
        }
        onStarted: client.transportStarted()
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            client.transportExited(exitCode);
        }
    }

    Timer {
        id: retryTimer
        interval: client.initialRetryInterval
        onTriggered: client.start()
    }
}
