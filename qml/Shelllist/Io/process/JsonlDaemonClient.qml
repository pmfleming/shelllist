import Quickshell.Io
import QtQuick
import "../JsonlRouting.js" as Routing

Item {
    id: client

    required property string daemonName
    required property var streams
    required property bool active
    property bool ready
    required property bool recoverProtocolErrors
    property var queuedLines: []
    property var counters: ({ sequence: 0, retryAttempt: 0 })
    property string subscriptionId: ""
    property int initialRetryInterval: 1500
    property int maximumRetryInterval: 30000

    signal response(string id, var envelope, string transportError)
    signal eventReceived(var event)
    signal transportFailed(string message)

    function start() {
        if (!active || process.running || retryTimer.running)
            return;
        process.stdinEnabled = true;
        try {
            console.info("shelllist transport starting daemon=" + daemonName);
            process.exec([daemonName, "client"]);
        } catch (error) {
            process.stdinEnabled = false;
            const message = "Could not start " + daemonName + " client: " + error;
            console.error("shelllist transport failed daemon=" + daemonName + " stage=start error=" + error);
            transportFailed(message);
            scheduleRetry();
        }
    }

    function stop() {
        retryTimer.stop();
        queuedLines = [];
        if (!process.running)
            return;
        if (ready) {
            try {
                if (subscriptionId.length > 0)
                    cancel("cancel-subscription-" + (++counters.sequence), subscriptionId);
                send({ id: "shutdown-" + (++counters.sequence), op: "shutdown" });
            } catch (error) {
                console.error("shelllist transport shutdown failed daemon=" + daemonName + " error=" + error);
            }
        }
        subscriptionId = "";
        process.stdinEnabled = false;
    }

    function call(id, method, params) { send({ id: id, op: "call", method: method, params: params || ({}) }); }
    function cancel(idOrRequestId, optionalRequestId) {
        const requestId = optionalRequestId || idOrRequestId;
        if (!requestId)
            return;
        const id = optionalRequestId ? idOrRequestId : "cancel-" + (++counters.sequence);
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
        if (message.id === "session-subscribe" && message.ok)
            subscriptionId = Routing.subscriptionId(message);
    }
    function markHealthy() { counters.retryAttempt = 0; }
    function scheduleRetry() {
        if (!active)
            return;
        retryTimer.interval = Math.min(maximumRetryInterval, initialRetryInterval * Math.pow(2, counters.retryAttempt));
        counters.retryAttempt = Math.min(counters.retryAttempt + 1, 30);
        console.warn("shelllist transport retry scheduled daemon=" + daemonName + " delay_ms=" + retryTimer.interval
            + " attempt=" + counters.retryAttempt);
        retryTimer.restart();
    }
    function handleResponse(message) {
        const outcome = Routing.responseOutcome(message, daemonName);
        if (outcome.recover) {
            console.error("shelllist transport subscription failed daemon=" + daemonName + " error=" + outcome.error);
            response(outcome.id, null, outcome.error);
            recover(outcome.error);
            return;
        }
        markHealthy();
        rememberSubscription(message);
        response(outcome.id, outcome.envelope, outcome.error);
    }
    function recover(message) {
        transportFailed(message);
        if (!active)
            return;
        try {
            stop();
        } finally {
            scheduleRetry();
        }
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
        if (Routing.isFailureKind(message.kind)) {
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
            counters.retryAttempt = 0;
        }
    }

    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: function (line) { client.handleLine(line); } }
        stderr: StdioCollector { id: processError; waitForEnd: true }
        onStarted: {
            console.info("shelllist transport started daemon=" + client.daemonName);
            client.ready = true;
            try {
                client.subscribe();
                client.flushQueue();
            } catch (error) {
                client.recover("Could not initialize " + client.daemonName + " client: " + error);
            }
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            client.ready = false;
            if (!client.active)
                return;
            const detail = processError.text.length > 0 ? processError.text : "exit " + exitCode;
            console.error("shelllist transport exited daemon=" + client.daemonName + " detail=" + detail);
            client.transportFailed(client.daemonName + " client stopped: " + detail);
            if (!retryTimer.running)
                client.scheduleRetry();
        }
    }

    Timer { id: retryTimer; interval: client.initialRetryInterval; onTriggered: client.start() }
}
