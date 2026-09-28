import QtQuick
import Quickshell.Io
import "../HyprlandSettings.js" as Settings

Item {
    id: client
    property list<string> pendingCommand: []
    function applyStyle(namespace: string, noMotion: bool, blur: bool): void {
        applyCommand(Settings.layerStyle(namespace, noMotion, blur));
    }
    function apply(rule: string): void {
        applyCommand(["hyprctl", "keyword", "layerrule", rule]);
    }
    function applyCommand(command: var): void {
        if (process.running) {
            pendingCommand = command;
            return;
        }
        process.exec(command);
    }
    function applyPending(): void {
        if (!pendingCommand.length)
            return;
        const command = Array.from(pendingCommand);
        pendingCommand = [];
        applyCommand(command);
    }
    Process {
        id: process
        // Quickshell's qmltypes omit QProcess::ExitStatus; keep this scoped.
        // qmllint disable signal-handler-parameters
        onExited: client.applyPending()
        // qmllint enable signal-handler-parameters
    }
}
