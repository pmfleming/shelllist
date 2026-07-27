import QtQuick
import Shelllist.Core as Core

Item {
    id: capture

    property bool active: false
    property bool inFlight: false

    signal completed(string message)
    signal failed(string message)

    function captureRegion(x, y, width, height) {
        if (!active || inFlight || width < 1 || height < 1)
            return false;
        inFlight = true;
        client.call("capture-screenshot", "clipboard.capture.screenshot", {
            x: Math.round(x),
            y: Math.round(y),
            width: Math.round(width),
            height: Math.round(height)
        });
        return true;
    }

    function finish(envelope, transportError) {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "clip-api", 1, "clip-daemon", "Screenshot capture failed");
        if (error) {
            inFlight = false;
            failed(error);
            return;
        }
        const operation = (envelope.data || ({})).operation || null;
        if (!operation || operation.action !== "screenshot" || operation.status !== "completed") {
            inFlight = false;
            failed(operation && operation.message ? operation.message : "clip-daemon returned an invalid screenshot result");
            return;
        }
        inFlight = false;
        completed(operation.message || "Screenshot copied to the clipboard");
    }

    onActiveChanged: if (!active) inFlight = false

    JsonlDaemonClient {
        id: client
        daemonName: "clip-daemon"
        streams: ["clipboard.operation"]
        recoverProtocolErrors: true
        active: capture.active
        onResponse: function (id, envelope, transportError) {
            if (id === "capture-screenshot")
                capture.finish(envelope, transportError);
        }
        onTransportFailed: function (message) {
            if (capture.inFlight) {
                capture.inFlight = false;
                capture.failed(message);
            }
        }
    }
}
