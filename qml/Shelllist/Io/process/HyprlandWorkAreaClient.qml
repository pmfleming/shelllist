import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../HyprlandWorkArea.js" as WorkArea

Item {
    id: client

    property bool active: false
    property string monitorName: ""
    property var snapshot: null
    property bool ready: false
    property bool refreshPending: false
    property bool requestRunning: false
    property int generation: 0
    property int requestGeneration: 0
    property string reply: ""
    readonly property var insets: WorkArea.insets(snapshot, monitorName)

    function refresh(): void {
        if (!active)
            return;
        if (requestRunning || process.running) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        requestGeneration = generation;
        requestRunning = true;
        reply = "";
        try {
            process.exec(["hyprctl", "--batch", "-j", "monitors; workspaces; workspacerules; clients; getoption general:gaps_out"]);
            watchdog.restart();
        } catch (error) {
            requestRunning = false;
            ready = true;
            console.warn("Shelllist workspace geometry:", error);
        }
    }

    function scheduleRefresh(): void {
        if (active)
            debounce.restart();
    }

    onActiveChanged: {
        if (active) {
            ++generation;
            ready = false;
            refresh();
        } else {
            debounce.stop();
            refreshPending = false;
        }
    }
    onMonitorNameChanged: scheduleRefresh()

    Connections {
        target: Hyprland
        enabled: client.active
        function onRawEvent(event): void {
            if (WorkArea.geometryEvent(event.name))
                client.scheduleRefresh();
        }
    }

    Timer {
        id: debounce
        interval: 30
        onTriggered: client.refresh()
    }
    Timer {
        // Runtime `hyprctl keyword` changes do not always emit configreloaded.
        // Poll only while this surface is open, never while the host is idle.
        interval: 1000
        repeat: true
        running: client.active
        onTriggered: client.refresh()
    }
    Timer {
        id: watchdog
        interval: 2000
        onTriggered: {
            // Also retire failed starts: these need not emit Process.exited.
            client.requestRunning = false;
            if (process.running)
                process.signal(9);
            if (client.active && client.requestGeneration === client.generation)
                client.ready = true;
            if (client.refreshPending)
                client.scheduleRefresh();
        }
    }
    Process {
        id: process
        stdout: StdioCollector {
            onStreamFinished: client.reply = text
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            watchdog.stop();
            client.requestRunning = false;
            const current = client.active && client.requestGeneration === client.generation;
            if (current && exitCode === 0) {
                try {
                    const next = WorkArea.parseBatch(client.reply);
                    if (JSON.stringify(next) !== JSON.stringify(client.snapshot))
                        client.snapshot = next;
                } catch (error) {
                    console.warn("Shelllist workspace geometry:", error);
                }
            }
            if (current)
                client.ready = true;
            if (client.refreshPending)
                client.scheduleRefresh();
        }
    }
}
