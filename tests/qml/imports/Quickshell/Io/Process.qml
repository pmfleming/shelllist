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
        // Generic ranking shares the bar transport. Tests inject authoritative
        // replies; this inert transport never launches a daemon or helper.
        if (command.length === 2 && command[0] === "bar-daemon" && command[1] === "client") {
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
