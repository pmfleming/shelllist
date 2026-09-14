import Quickshell.Io
import QtQuick

Item {
    id: qr

    required property Item controller
    property bool open: false
    property string payload: ""
    property string networkName: ""
    property string password: ""
    property string imageSource: ""
    property string error: ""
    property int generation: 0

    /// Emitted with a scanned Wi-Fi QR payload. The payload carries a
    /// passphrase, so the handler must pass it straight to the daemon.
    signal scanned(string payload, bool join)
    signal copyRequested(string text, string message)

    function begin(name) {
        close();
        networkName = name;
        open = true;
    }

    function show(result) {
        payload = result.qr_payload || "";
        password = result.password || "";
        imageSource = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(result.qr_svg);
        error = "";
    }

    function close() {
        open = false;
        payload = "";
        password = "";
        imageSource = "";
        error = "";
        networkName = "";
        generation += 1;
    }

    function copyPayload() {
        if (!payload.length)
            return;
        copyRequested(payload, "Wi-Fi QR payload copied to clipboard");
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
        id: scanner
        stdout: StdioCollector {
            id: scannedOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: scannerError
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: function (exitCode: int): void {
            qr.finishScanning(exitCode);
        }
        // qmllint enable signal-handler-parameters
    }
}
