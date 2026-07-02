import Quickshell.Io
import QtQuick

Item {
    required property var controller
    readonly property bool running: shareCheckProc.running

    function check(path) { shareCheckProc.exec(Wifi.nmApiArgs("wifi", "profile", "share", path)); }

    Process {
        id: shareCheckProc
        stdout: StdioCollector { id: shareCheckOut; waitForEnd: true }
        stderr: StdioCollector { id: shareCheckErr; waitForEnd: true }
        onExited: function (exitCode, exitStatus) { controller.applyShareCheckOutput(shareCheckOut.text, shareCheckErr.text); }
    }
}
