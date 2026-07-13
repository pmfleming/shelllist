import Quickshell.Io
import QtQuick
import "NmApi.js" as NmApi

Item {
    id: client

    property bool active: false
    property bool ready: false
    property var queuedLines: []
    property int sequence: 0
    readonly property bool running: process.running

    signal response(string id, var envelope, string transportError)
    signal eventReceived(var event)
    signal transportFailed(string message)

    function start() {
        if (!active || process.running)
            return;
        process.stdinEnabled = true;
        process.exec(["nm-daemon", "client"]);
    }

    function stop() {
        retryTimer.stop();
        queuedLines = [];
        if (!process.running)
            return;
        if (ready)
            send({ id: "shutdown-" + (++sequence), op: "shutdown" });
        process.stdinEnabled = false;
    }

    function call(id, method, params) {
        send({ id: id, op: "call", method: method, params: params || ({}) });
    }

    function cancel(requestId) {
        if (requestId && requestId.length > 0)
            send({ id: "cancel-" + (++sequence), op: "cancel", request_id: requestId });
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

    function subscribe() {
        send({ id: "session-subscribe", op: "subscribe", streams: NmApi.subscribedStreams });
    }

    function handleLine(line) {
        try {
            const message = JSON.parse(line);
            if (message.kind === "event") {
                eventReceived(message.event);
                return;
            }
            if (message.kind === "response") {
                response(message.id || "", message.ok ? message.response : null, message.ok ? "" : (message.error || "D-Bus request failed"));
                return;
            }
            if (message.kind === "transport-error" || message.kind === "protocol-error")
                transportFailed(message.error || "nm-daemon client transport failed");
        } catch (error) {
            transportFailed("Could not parse nm-daemon client output: " + error);
        }
    }

    Component.onCompleted: start()
    onActiveChanged: active ? start() : stop()

    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { client.handleLine(line); }
        }
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
            client.transportFailed("nm-daemon client stopped: " + detail);
            retryTimer.restart();
        }
    }

    Timer {
        id: retryTimer
        interval: 1500
        repeat: false
        onTriggered: client.start()
    }
}
