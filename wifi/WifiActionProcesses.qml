import Quickshell.Io
import QtQuick
import "Wifi.js" as Wifi

// Quickshell 0.3's qmltypes expose Process.exited(exitCode,
// QProcess::ExitStatus), but QProcess::ExitStatus is not resolvable to
// the linter in this package set. The handlers below only need exitCode.
// qmllint disable signal-handler-parameters
Item {
    required property var controller
    property bool connectUsesStdin: false
    property string connectStdinText: ""
    property bool replacingConnect: false
    property var pendingConnectArgs: []
    property string pendingConnectStdinText: ""
    property bool pendingConnectUsesStdin: false

    readonly property bool nonConnectRunning: disconnectProc.running || profileProc.running
    readonly property bool running: connectProc.running || nonConnectRunning
    readonly property bool connectRunning: connectProc.running

    function startConnect(args, stdinText) {
        connectUsesStdin = stdinText !== undefined && stdinText !== null;
        connectStdinText = connectUsesStdin ? stdinText : "";
        connectProc.stdinEnabled = connectUsesStdin;
        connectProc.exec(args);
    }
    function queueReplacementConnect(args, stdinText) {
        pendingConnectArgs = args;
        pendingConnectUsesStdin = stdinText !== undefined && stdinText !== null;
        pendingConnectStdinText = pendingConnectUsesStdin ? stdinText : "";
        replacingConnect = true;
        connectProc.signal(15);
    }
    function runPendingConnect() {
        const args = pendingConnectArgs;
        const stdinText = pendingConnectUsesStdin ? pendingConnectStdinText : undefined;
        pendingConnectArgs = [];
        pendingConnectStdinText = "";
        pendingConnectUsesStdin = false;
        replacingConnect = false;
        startConnect(args, stdinText);
    }
    function runConnect(args, stdinText) {
        if (connectProc.running)
            return queueReplacementConnect(args, stdinText);
        startConnect(args, stdinText);
    }
    function disconnect() { disconnectProc.exec(Wifi.nmApiArgs("wifi", "disconnect")); }
    function deleteProfile(path) { profileProc.exec(Wifi.nmApiArgs("wifi", "profile", "delete", path)); }
    function setAutoconnect(path, enabled) { profileProc.exec(Wifi.nmApiArgs("wifi", "profile", "autoconnect", path, enabled ? "true" : "false")); }
    function setMacRandomization(path, enabled) { profileProc.exec(Wifi.nmApiArgs("wifi", "profile", "mac-randomization", path, enabled ? "true" : "false")); }
    function setSendHostname(path, enabled) { profileProc.exec(Wifi.nmApiArgs("wifi", "profile", "send-hostname", path, enabled ? "true" : "false")); }
    function openPortal() { if (!portalProc.running) portalProc.exec(["shelllist-captive-portal"]); }
    function resetConnectAttempt() { connectStdinText = ""; connectUsesStdin = false; controller.resetConnectProgress(); connectProc.stdinEnabled = false; }
    function finishParsedConnect(result, errorText) { controller.applyConnectResult(result, errorText); if (result.status !== "error") controller.refresh(); }
    function finishUnparsedConnect(exitCode, networkName, errorText, parseError) { if (exitCode !== 0) { controller.status = "Connect failed: " + (errorText || parseError); return; } controller.status = "Connected to " + networkName + "; could not parse connect result: " + parseError; controller.refresh(); }
    function finishConnect(exitCode, networkName, outputText, errorText) { resetConnectAttempt(); try { finishParsedConnect(Wifi.apiResult(JSON.parse(outputText), "result"), errorText); } catch (error) { finishUnparsedConnect(exitCode, networkName, errorText, error); } }
    function finishOrReplaceConnect(exitCode, networkName, outputText, errorText) { if (replacingConnect) return runPendingConnect(); finishConnect(exitCode, networkName, outputText, errorText); }

    Process {
        id: connectProc
        stdout: StdioCollector { id: connectOut; waitForEnd: true }
        stderr: StdioCollector { id: connectErr; waitForEnd: true }
        onStarted: {
            if (connectUsesStdin) {
                connectProc.write(connectStdinText + "\n");
                connectStdinText = "";
                // The network API connect-target reads stdin with read_to_string(),
                // so it must see EOF before it can connect and exit. Quickshell
                // Process.write() only writes bytes; disabling stdin closes the
                // write channel after the queued payload.
                connectProc.stdinEnabled = false;
            }
        }
        onExited: function (exitCode) { finishOrReplaceConnect(exitCode, controller.connectingNetworkName || "network", connectOut.text, connectErr.text); }
    }

    Process {
        id: disconnectProc
        stdout: StdioCollector { id: disconnectOut; waitForEnd: true }
        stderr: StdioCollector { id: disconnectErr; waitForEnd: true }
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                controller.status = "Disconnect failed: " + disconnectErr.text;
                return;
            }
            try {
                const result = Wifi.apiResult(JSON.parse(disconnectOut.text), "result");
                controller.status = result.message || "Disconnected Wi-Fi";
            } catch (error) {
                controller.status = "Disconnected Wi-Fi";
            }
            controller.refresh();
        }
    }

    Process {
        id: profileProc
        stdout: StdioCollector { id: profileOut; waitForEnd: true }
        stderr: StdioCollector { id: profileErr; waitForEnd: true }
        onExited: function (exitCode) {
            try {
                const result = Wifi.apiResult(JSON.parse(profileOut.text), "result");
                if (exitCode !== 0 || result.status === "error") {
                    controller.status = "Profile action failed: " + (result.message || profileErr.text);
                    return;
                }
                controller.status = result.message || "Saved profile updated";
            } catch (error) {
                if (exitCode !== 0) {
                    controller.status = "Profile action failed: " + (profileErr.text || error);
                    return;
                }
                controller.status = "Saved profile updated";
            }
            controller.refresh();
        }
    }

    Process {
        id: portalProc
        stderr: StdioCollector { id: portalErr; waitForEnd: false }
        onExited: function (exitCode) {
            if (exitCode !== 0 && portalErr.text.length > 0)
                controller.status = "Could not open captive portal browser: " + portalErr.text;
        }
    }
}
