import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../HyprlandSettings.js" as Settings

Item {
    id: client
    property bool active: false
    property bool reduced: false
    property bool pending: false
    function refresh(): void {
        if (!active)
            return;
        if (reader.running) {
            pending = true;
            return;
        }
        pending = false;
        reader.exec(["hyprctl", "-j", "getoption", "animations:enabled"]);
    }
    onActiveChanged: if (active) refresh(); else reduced = false
    Component.onCompleted: if (active) refresh()
    Connections {
        target: client.active ? Hyprland : null
        function onRawEvent(event): void {
            if (event.name === "configreloaded")
                client.refresh();
        }
    }
    Process {
        id: reader
        onRunningChanged: {
            if (running)
                deadline.restart();
            else {
                deadline.stop();
                if (client.pending)
                    Qt.callLater(client.refresh);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!client.active)
                    return;
                try {
                    const option = JSON.parse(text);
                    if (option.int !== undefined || option.bool !== undefined)
                        client.reduced = !!Settings.motionDisabled(option);
                } catch (_) {} // Failed reads retain the last known preference.
            }
        }
    }
    Timer {
        id: deadline
        interval: 1500
        onTriggered: reader.running = false
    }
}
