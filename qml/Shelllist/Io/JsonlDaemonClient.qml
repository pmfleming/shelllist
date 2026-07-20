import Quickshell.Io
import QtQuick

Item {
    id: client

    required property string daemonName
    required property var streams
    property bool active: false
    property bool ready: false
    property bool recoverProtocolErrors: false
    property var queuedLines: []
    property int sequence: 0
    property string subscriptionId: ""
    property int retryAttempt: 0
    property int initialRetryInterval: 1500
    property int maximumRetryInterval: 30000

    signal response(string id, var envelope, string transportError)
    signal eventReceived(var event)
    signal transportFailed(string message)

    function start() {
        if (!active || process.running || retryTimer.running)
            return;
        process.stdinEnabled = true;
        process.exec([daemonName, "client"]);
    }

    function stop() {
        retryTimer.stop();
        queuedLines = [];
        if (!process.running)
            return;
        if (ready) {
            if (subscriptionId.length > 0)
                cancel("cancel-subscription-" + (++sequence), subscriptionId);
            send({ id: "shutdown-" + (++sequence), op: "shutdown" });
        }
        subscriptionId = "";
        process.stdinEnabled = false;
    }

    function call(id, method, params) { send({ id: id, op: "call", method: method, params: params || ({}) }); }
    function cancel(idOrRequestId, optionalRequestId) {
        const requestId = optionalRequestId || idOrRequestId;
        if (!requestId)
            return;
        const id = optionalRequestId ? idOrRequestId : "cancel-" + (++sequence);
        send({ id: id, op: "cancel", request_id: requestId });
    }

    function send(message) {
        const line = JSON.stringify(message);
        if (!ready) {
            queuedLines = queuedLines.concat([line]);
            start();
            return;
        }
        process.write(line + "\n");
    }

    function flushQueue() {
        const lines = queuedLines;
        queuedLines = [];
        for (let index = 0; index < lines.length; index++)
            process.write(lines[index] + "\n");
    }

    function subscribe() { send({ id: "session-subscribe", op: "subscribe", streams: streams }); }
    function rememberSubscription(message) {
        if (message.id !== "session-subscribe" || !message.ok || !message.response || !message.response.data)
            return;
        subscriptionId = (message.response.data.subscription || ({})).id || "";
    }
    function markHealthy() { retryAttempt = 0; }
    function scheduleRetry() {
        if (!active)
            return;
        retryTimer.interval = Math.min(maximumRetryInterval, initialRetryInterval * Math.pow(2, retryAttempt));
        retryAttempt = Math.min(retryAttempt + 1, 30);
        retryTimer.restart();
    }
    function handleResponse(message) {
        markHealthy();
        rememberSubscription(message);
        response(message.id || "", message.ok ? message.response : null,
            message.ok ? "" : (message.error || daemonName + " call failed"));
    }
    function recover(message) {
        transportFailed(message);
        if (!active)
            return;
        stop();
        scheduleRetry();
    }
    function handleMessage(message) {
        if (message.kind === "event") {
            markHealthy();
            eventReceived(message.event || ({}));
            return;
        }
        if (message.kind === "response") {
            handleResponse(message);
            return;
        }
        if (message.kind === "transport-error" || message.kind === "protocol-error") {
            const detail = message.error || daemonName + " client failed";
            if (recoverProtocolErrors)
                recover(detail);
            else
                transportFailed(detail);
        }
    }
    function handleLine(line) {
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

    Component.onCompleted: start()
    onActiveChanged: {
        if (active) {
            start();
        } else {
            stop();
            retryAttempt = 0;
        }
    }

    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: function (line) { client.handleLine(line); } }
        stderr: StdioCollector { id: processError; waitForEnd: true }
        onStarted: {
            client.ready = true;
            client.subscribe();
            client.flushQueue();
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            client.ready = false;
            if (!client.active)
                return;
            const detail = processError.text.length > 0 ? processError.text : "exit " + exitCode;
            client.transportFailed(client.daemonName + " client stopped: " + detail);
            if (!retryTimer.running)
                client.scheduleRetry();
        }
    }

    Timer { id: retryTimer; interval: client.initialRetryInterval; onTriggered: client.start() }
}
