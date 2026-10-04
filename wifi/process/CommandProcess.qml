import Quickshell.Io
import QtQuick

Item {
    id: command

    readonly property alias running: process.running
    property bool stdoutWaitForEnd: true
    property bool stderrWaitForEnd: true
    signal finished(int exitCode, string output, string errorOutput)
    signal startFailed
    property bool awaitingResult: false
    property bool didStart: false

    function exec(args) {
        awaitingResult = true;
        didStart = false;
        process.exec(args);
    }
    Process {
        id: process
        objectName: "portalChildProcess"
        onStarted: command.didStart = true
        // Quickshell does not emit exited when exec itself fails. That path
        // only changes running back to false and has no browser side effect.
        onRunningChanged: {
            if (!running && command.awaitingResult && !command.didStart) {
                command.awaitingResult = false;
                command.startFailed();
            }
        }
        stdout: StdioCollector {
            id: stdoutCollector
            waitForEnd: command.stdoutWaitForEnd
        }
        stderr: StdioCollector {
            id: stderrCollector
            waitForEnd: command.stderrWaitForEnd
        }
        // Quickshell's qmltypes omit QProcess::ExitStatus; keep this scoped.
        // qmllint disable signal-handler-parameters
        onExited: function (exitCode: int): void {
            if (command.awaitingResult) {
                command.awaitingResult = false;
                command.finished(exitCode, stdoutCollector.text, stderrCollector.text);
            }
        }
        // qmllint enable signal-handler-parameters
    }
}
