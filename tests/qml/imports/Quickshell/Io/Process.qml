import QtQml

// Controller tests must never launch daemon clients.
QtObject {
    property bool running: false
    property bool stdinEnabled: false
    property var environment: ({})
    property QtObject stdout
    property QtObject stderr
    signal started
    signal exited(int exitCode)

    function exec(command) {
        throw new Error("Process execution disabled in tests");
    }
    function write(data) {
        throw new Error("Process writes disabled in tests");
    }
}
