import QtQuick
import Quickshell.Io

Item {
    id: client
    property list<string> pendingCommand: []
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
