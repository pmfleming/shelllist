import QtQml

// Controller tests must never launch daemon clients.
QtObject {
    property bool running: false
    property bool stdinEnabled: false
    property var environment: ({})
    // Opt-in deterministic process lifecycle; still never launches a command.
    property bool simulated: false
    property var commands: []
    property var writes: []
    property QtObject stdout
    property QtObject stderr
    signal started
    signal exited(int exitCode)

    function exec(command) {
        // Search now starts for empty queries too. UI tests inject authoritative
        // rankings; exercise the worker separately rather than starting a process.
        if (command.length === 1 && command[0] === "shelllist-search") {
            simulated = true;
            commands = commands.concat([command]);
            running = true;
            started();
            return;
        }
        if (!simulated)
            throw new Error("Process execution disabled in tests");
        commands = commands.concat([command]);
        running = true;
    }
    function write(data) {
        if (!simulated || !stdinEnabled)
            throw new Error("Process writes disabled in tests");
        writes = writes.concat([data]);
    }
}
