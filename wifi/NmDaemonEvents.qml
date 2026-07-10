import Quickshell.Io
import QtQuick

Item {
    id: daemonEvents

    required property var controller
    readonly property bool running: eventProc.running

    function start() {
        if (!eventProc.running)
            eventProc.exec(["shelllist-nm-daemon-events", "wifi.scan", "wifi.connect", "wifi.secret"]);
    }

    Component.onCompleted: start()

    Process {
        id: eventProc
        stdout: SplitParser { splitMarker: "\n"; onRead: function (data) { daemonEvents.controller.handleDaemonEvent(data); } }
        stderr: StdioCollector { id: eventErr; waitForEnd: true }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            if (exitCode !== 0 && eventErr.text.length > 0)
                daemonEvents.controller.status = "nm-daemon event stream failed: " + eventErr.text;
            retryTimer.restart();
        }
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        onTriggered: daemonEvents.start()
    }
}
