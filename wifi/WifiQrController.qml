import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: qr

    required property WifiController controller
    property bool open: false
    property string payload: ""
    property string networkName: ""
    property string password: ""
    property string imageSource: ""
    property string error: ""
    property string outputPath: ""
    property int generation: 0
    readonly property bool rendering: renderer.running

    function runtimeDirectory() {
        return Quickshell.env("XDG_RUNTIME_DIR") || "";
    }

    function payloadField(qrPayload, requestedKey) {
        const value = String(qrPayload || "").replace(/^WIFI:/, "");
        let field = "";
        let escaped = false;
        const fields = [];
        for (let index = 0; index < value.length; index++) {
            const character = value[index];
            if (escaped) {
                field += character;
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === ";") {
                fields.push(field);
                field = "";
            } else {
                field += character;
            }
        }
        for (let index = 0; index < fields.length; index++) {
            if (fields[index].indexOf(requestedKey + ":") === 0)
                return fields[index].slice(requestedKey.length + 1);
        }
        return "";
    }

    function show(qrPayload, name) {
        if (outputPath.length > 0)
            cleaner.exec(["rm", "-f", outputPath]);
        payload = qrPayload;
        networkName = name;
        password = payloadField(qrPayload, "P");
        imageSource = "";
        error = "";
        open = true;
        generation += 1;
        const runtime = runtimeDirectory();
        if (!runtime.length) {
            error = "XDG_RUNTIME_DIR is unavailable; refusing to write a secret-bearing QR image to shared temporary storage.";
            return;
        }
        outputPath = runtime + "/shelllist-wifi-qr-" + generation + ".svg";
        renderer.exec(["qrencode", "--type=SVG", "--output", outputPath]);
    }

    function close() {
        open = false;
        payload = "";
        password = "";
        imageSource = "";
        error = "";
        if (outputPath.length > 0)
            cleaner.exec(["rm", "-f", outputPath]);
    }

    function copyPayload() {
        if (!payload.length)
            return;
        Quickshell.clipboardText = payload;
        controller.status = "Wi-Fi QR payload copied to clipboard";
    }

    function launchScanner() {
        if (scanner.running) {
            controller.status = "Wi-Fi QR scanner is already open";
            return false;
        }
        scanner.exec(["qrca"]);
        controller.status = "Opening Wi-Fi QR scanner…";
        return true;
    }

    Process {
        id: renderer
        stdinEnabled: true
        stderr: StdioCollector { id: renderError; waitForEnd: true }
        onStarted: {
            // Keep secret-bearing QR payloads off argv and process listings.
            renderer.write(qr.payload);
            renderer.stdinEnabled = false;
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            if (!qr.open) {
                if (qr.outputPath.length > 0)
                    cleaner.exec(["rm", "-f", qr.outputPath]);
            } else if (exitCode === 0) {
                qr.imageSource = "file://" + qr.outputPath;
            } else {
                qr.error = renderError.text.length > 0 ? renderError.text : "QR renderer exited with " + exitCode;
            }
        }
    }

    Process { id: cleaner }

    Process {
        id: scanner
        stderr: StdioCollector { id: scannerError; waitForEnd: true }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            if (exitCode !== 0) {
                const detail = scannerError.text.length > 0 ? scannerError.text : "exit " + exitCode;
                qr.controller.status = "Wi-Fi QR scanner failed: " + detail;
            }
        }
    }
}
