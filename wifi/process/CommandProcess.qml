import Quickshell.Io
import QtQuick

Item {
    id: command

    readonly property alias running: process.running
    property bool stdoutWaitForEnd: true
    property bool stderrWaitForEnd: true
    signal finished(int exitCode, string output, string errorOutput)

    function exec(args) {
        process.exec(args);
    }
    Process {
        id: process
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
            command.finished(exitCode, stdoutCollector.text, stderrCollector.text);
        }
        // qmllint enable signal-handler-parameters
    }
}
