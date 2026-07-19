import Quickshell.Io
import QtQuick

Item {
    id: client

    property bool active: false
    property bool ready: false
    property var queuedLines: []
    property int sequence: 0

    signal response(string id, var envelope, string transportError)
    signal transportFailed(string message)

    function start() {
        if (!active || process.running)
            return;
        process.stdinEnabled = true;
        process.exec(["bt-daemon", "client"]);
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
    function call(id, method, params) { send({ id: id, op: "call", method: method, params: params || ({}) }); }
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
    function handleLine(line) {
        try {
            const message = JSON.parse(line);
            if (message.kind === "response") {
                response(message.id || "", message.ok ? message.response : null, message.ok ? "" : (message.error || "bt-daemon call failed"));
            } else if (message.kind === "transport-error" || message.kind === "protocol-error") {
                transportFailed(message.error || "bt-daemon client failed");
            }
        } catch (error) {
            transportFailed("Could not parse bt-daemon output: " + error);
        }
    }

    Component.onCompleted: start()
    onActiveChanged: active ? start() : stop()

    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: function (line) { client.handleLine(line); } }
        stderr: StdioCollector { id: processError; waitForEnd: true }
        onStarted: {
            client.ready = true;
            client.flushQueue();
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            client.ready = false;
            if (!client.active)
                return;
            client.transportFailed("bt-daemon client stopped: " + (processError.text || ("exit " + exitCode)));
            retryTimer.restart();
        }
    }

    Timer { id: retryTimer; interval: 1500; onTriggered: client.start() }
}
