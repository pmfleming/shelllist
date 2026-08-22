import Quickshell
import Quickshell.Io
import QtQuick
import "../WifiQr.js" as WifiQr

Item {
    id: qr

    required property Item controller
    property bool open: false
    property string payload: ""
    property string networkName: ""
    property string password: ""
    property string imageSource: ""
    property string error: ""
    property string outputPath: ""
    property int generation: 0

    /// Emitted with a scanned Wi-Fi QR payload. The payload carries a
    /// passphrase, so the handler must pass it straight to the daemon.
    signal scanned(string payload, bool join)

    function runtimeDirectory() {
        return Quickshell.env("XDG_RUNTIME_DIR") || "";
    }

    function show(qrPayload, name) {
        if (outputPath.length > 0)
            cleaner.exec(["rm", "-f", outputPath]);
        payload = qrPayload;
        networkName = name;
        password = WifiQr.payloadField(qrPayload, "P");
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

    // Set when the scanner should join the scanned network rather than only
    // report what it read.
    property bool joinAfterScan: false

    function launchScanner(join) {
        if (scanner.running) {
            controller.status = "Wi-Fi QR scanner is already open";
            return false;
        }
        joinAfterScan = !!join;
        scanner.exec(["qrca"]);
        controller.status = "Opening Wi-Fi QR scanner…";
        return true;
    }

    function finishRendering(exitCode) {
        if (!open) {
            if (outputPath.length > 0) cleaner.exec(["rm", "-f", outputPath]);
        } else if (exitCode === 0) {
            imageSource = "file://" + outputPath;
        } else {
            error = renderError.text.length > 0 ? renderError.text : "QR renderer exited with " + exitCode;
        }
    }

    function finishScanning(exitCode) {
        if (exitCode !== 0) {
            const detail = scannerError.text.length > 0 ? scannerError.text : "exit " + exitCode;
            controller.status = "Wi-Fi QR scanner failed: " + detail;
            joinAfterScan = false;
            return;
        }
        // The scanned payload carries a passphrase, so it goes straight to the
        // daemon for validation and is never logged or kept here.
        const scannedText = scannedOutput.text.trim();
        const join = joinAfterScan;
        joinAfterScan = false;
        if (scannedText.length === 0) {
            controller.status = "Nothing was scanned.";
            return;
        }
        qr.scanned(scannedText, join);
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
        onExited: function (exitCode) { qr.finishRendering(exitCode); } // qmllint disable signal-handler-parameters
    }

    Process { id: cleaner }

    Process {
        id: scanner
        stdout: StdioCollector { id: scannedOutput; waitForEnd: true }
        stderr: StdioCollector { id: scannerError; waitForEnd: true }
        onExited: function (exitCode) { qr.finishScanning(exitCode); } // qmllint disable signal-handler-parameters
    }
}
