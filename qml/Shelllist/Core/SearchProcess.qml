import Quickshell.Io
import QtQuick

Item {
    id: bridge

    readonly property bool running: process.running
    property bool ready: false

    signal processReady
    signal lineReceived(string line)
    signal stopped(string error)

    function start(): void {
        if (process.running)
            return;
        process.stdinEnabled = true;
        process.exec(["shelllist-search"]);
    }

    function write(line: string): void {
        process.write(line);
    }

    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { bridge.lineReceived(line); }
        }
        stderr: StdioCollector { id: processError; waitForEnd: true }
        onStarted: {
            bridge.ready = true;
            bridge.processReady();
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            bridge.ready = false;
            bridge.stopped(processError.text);
        }
    }
}
