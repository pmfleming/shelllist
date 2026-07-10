import QtQuick
import "Wifi.js" as Wifi
import "."

Item {
    id: sharing

    required property var controller
    readonly property bool running: shareCheckProc.running

    function check(path) { shareCheckProc.exec(Wifi.nmDaemonArgs("wifi", "profile", "share", path)); }

    CommandProcess {
        id: shareCheckProc
        onFinished: function (exitCode, outputText, errorText) { sharing.controller.applyShareCheckOutput(outputText, errorText); }
    }
}
