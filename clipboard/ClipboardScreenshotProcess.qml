import QtQuick
import Quickshell.Io
import Shelllist.Ui as Ui

Item {
    id: screenshot

    required property ClipboardController controller
    required property Ui.PopupWindowHost windowHost
    property string pendingGeometry: ""
    readonly property bool running: captureDelay.running || captureProcess.running

    function captureGeometry() {
        const width = Math.round(controller.currentWindowWidth);
        const x = Math.round(windowHost.targetWindowX()
            + (controller.surfaceWindowWidth - width) / 2);
        return x + "," + windowHost.targetWindowY() + " "
            + width + "x" + windowHost.currentWindowHeight;
    }

    function capture() {
        if (running)
            return false;
        pendingGeometry = captureGeometry();
        controller.screenshotInFlight = true;
        captureDelay.restart();
        return true;
    }

    Timer {
        id: captureDelay
        interval: 80
        repeat: false
        onTriggered: captureProcess.exec([
            "bash", "-c",
            "grim -g \"$1\" - | wl-copy --type image/png",
            "shelllist-clipboard-screenshot", screenshot.pendingGeometry
        ])
    }

    Process {
        id: captureProcess
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            screenshot.controller.screenshotInFlight = false;
            screenshot.controller.status = exitCode === 0
                ? "Clipboard screenshot copied"
                : "Could not capture the clipboard window";
        }
    }
}
