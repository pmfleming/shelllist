import Quickshell.Io
import QtQuick
import "Wifi.js" as Wifi
import "."

Item {
    id: actions

    required property var controller
    // Both are null when no stdin payload is involved.
    property var connectStdinText: null
    property var secretProvideStdinText: null

    readonly property bool nonConnectRunning: disconnectProc.running || profileProc.running || secretProvideProc.running
    readonly property bool running: connectRunning || nonConnectRunning
    readonly property bool connectRunning: connectStartProc.running || controller.activeConnectRequestId.length > 0

    function startConnect(args, stdinText) {
        connectStdinText = stdinText === undefined ? null : stdinText;
        connectStartProc.stdinEnabled = connectStdinText !== null;
        connectStartProc.exec(args);
    }
    function runConnect(args, stdinText) {
        if (!connectRunning)
            return startConnect(args, stdinText);
        controller.status = "Wait for the current Wi-Fi connection attempt to finish…";
    }
    function disconnect() { disconnectProc.exec(Wifi.nmDaemonArgs("wifi", "disconnect")); }
    function deleteProfile(path) { profileProc.exec(Wifi.nmDaemonArgs("wifi", "profile", "delete", path)); }
    function setAutoconnect(path, enabled) { profileProc.exec(Wifi.nmDaemonArgs("wifi", "profile", "autoconnect", path, enabled ? "true" : "false")); }
    function setMacRandomization(path, enabled) { profileProc.exec(Wifi.nmDaemonArgs("wifi", "profile", "mac-randomization", path, enabled ? "true" : "false")); }
    function setSendHostname(path, enabled) { profileProc.exec(Wifi.nmDaemonArgs("wifi", "profile", "send-hostname", path, enabled ? "true" : "false")); }
    function provideSecret(requestId, password, save) {
        secretProvideStdinText = JSON.stringify({ request_id: requestId, password: password, save: !!save });
        secretProvideProc.stdinEnabled = true;
        secretProvideProc.exec(["shelllist-nm-daemon-call", "wifi.secret.provide", "--stdin"]);
    }
    function openPortal() { if (!portalProc.running) portalProc.exec(["shelllist-captive-portal"]); }

    function finishConnectStart(exitCode, networkName, outputText, errorText) {
        connectStdinText = null;
        connectStartProc.stdinEnabled = false;
        if (exitCode !== 0) {
            controller.resetConnectProgress();
            controller.status = "Connect failed to start: " + errorText;
            controller.maybeRunPendingRefresh();
            return;
        }
        try {
            const result = Wifi.apiResult(JSON.parse(outputText), "result") || ({});
            if (result.status === "error") {
                controller.resetConnectProgress();
                controller.applyConnectResult(result, errorText);
                return;
            }
            controller.activeConnectRequestId = result.request_id || "";
            controller.status = result.message || ("Connecting to " + networkName + "…");
        } catch (parseError) {
            controller.resetConnectProgress();
            controller.status = "Connect failed: could not parse connect start response: " + parseError;
            controller.maybeRunPendingRefresh();
        }
    }

    function finishDisconnect(exitCode, outputText, errorText) {
        if (exitCode !== 0) {
            controller.status = "Disconnect failed: " + errorText;
            return;
        }
        try {
            const result = Wifi.apiResult(JSON.parse(outputText), "result");
            controller.status = result.message || "Disconnected Wi-Fi";
        } catch (error) {
            controller.status = "Disconnected Wi-Fi";
        }
        controller.refresh();
    }

    function failProfileAction(message) { controller.status = "Profile action failed: " + message; }
    function finishProfileAction(exitCode, outputText, errorText) {
        try {
            const result = Wifi.apiResult(JSON.parse(outputText), "result");
            if (exitCode !== 0 || result.status === "error")
                return failProfileAction(result.message || errorText);
            controller.status = result.message || "Saved profile updated";
        } catch (error) {
            if (exitCode !== 0)
                return failProfileAction(errorText || error);
            controller.status = "Saved profile updated";
        }
        controller.refresh();
    }

    function finishSecretProvide(exitCode, outputText, errorText) {
        secretProvideStdinText = null;
        secretProvideProc.stdinEnabled = false;
        if (exitCode !== 0) {
            controller.status = "Could not provide Wi-Fi secret: " + errorText;
            return;
        }
        try {
            const result = Wifi.apiResult(JSON.parse(outputText), "result") || ({});
            if (result.status === "error")
                controller.status = result.message || "Wi-Fi secret was not accepted";
        } catch (error) {
            controller.status = "Could not parse Wi-Fi secret response: " + error;
        }
    }

    Process {
        id: connectStartProc
        stdout: StdioCollector { id: connectOut; waitForEnd: true }
        stderr: StdioCollector { id: connectErr; waitForEnd: true }
        onStarted: {
            if (actions.connectStdinText !== null) {
                connectStartProc.write(actions.connectStdinText + "\n");
                actions.connectStdinText = null;
                connectStartProc.stdinEnabled = false;
            }
        }
        onExited: function (exitCode) { actions.finishConnectStart(exitCode, actions.controller.connectingNetworkName || "network", connectOut.text, connectErr.text); } // qmllint disable signal-handler-parameters
    }

    Process {
        id: secretProvideProc
        stdout: StdioCollector { id: secretProvideOut; waitForEnd: true }
        stderr: StdioCollector { id: secretProvideErr; waitForEnd: true }
        onStarted: {
            if (actions.secretProvideStdinText !== null) {
                secretProvideProc.write(actions.secretProvideStdinText + "\n");
                actions.secretProvideStdinText = null;
                secretProvideProc.stdinEnabled = false;
            }
        }
        onExited: function (exitCode) { actions.finishSecretProvide(exitCode, secretProvideOut.text, secretProvideErr.text); } // qmllint disable signal-handler-parameters
    }

    CommandProcess {
        id: disconnectProc
        onFinished: function (exitCode, outputText, errorText) { actions.finishDisconnect(exitCode, outputText, errorText); }
    }

    CommandProcess {
        id: profileProc
        onFinished: function (exitCode, outputText, errorText) { actions.finishProfileAction(exitCode, outputText, errorText); }
    }

    CommandProcess {
        id: portalProc
        stderrWaitForEnd: false
        onFinished: function (exitCode, outputText, errorText) {
            if (exitCode !== 0 && errorText.length > 0)
                actions.controller.status = "Could not open captive portal browser: " + errorText;
        }
    }
}
