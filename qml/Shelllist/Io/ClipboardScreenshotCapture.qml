import QtQuick
import "../../../clipboard/ClipApi.js" as ClipApi

Item {
    id: capture

    property bool active: false
    property bool blocked: false
    property bool inFlight: false
    property string startMessage: "Capturing window…"

    signal statusChanged(string message)

    function captureRegion(x: real, y: real, width: real, height: real): bool {
        if (!active || blocked || inFlight || width < 1 || height < 1)
            return false;
        inFlight = true;
        statusChanged(startMessage);
        client.call("capture-screenshot", ClipApi.methods.captureScreenshot, {
            x: Math.round(x),
            y: Math.round(y),
            width: Math.round(width),
            height: Math.round(height)
        });
        return true;
    }

    function reject(message: string): void {
        inFlight = false;
        statusChanged(message);
    }

    function operationFailure(operation: var): string {
        if (!operation)
            return "clip-daemon returned no screenshot result";
        if (operation.action !== "screenshot")
            return "clip-daemon returned an unexpected screenshot action";
        if (operation.status !== "completed")
            return operation.message || "Screenshot capture did not complete";
        return "";
    }

    function finish(envelope: var, transportError: string): void {
        const error = client.responseError(envelope, transportError,
            "Screenshot capture failed");
        if (error) {
            reject(error);
            return;
        }
        const operation = (envelope.data || ({})).operation || null;
        const failure = operationFailure(operation);
        if (failure.length > 0) {
            reject(failure);
            return;
        }
        const message = operation.message || "Screenshot copied to the clipboard";
        inFlight = false;
        statusChanged(message);
    }

    onActiveChanged: if (!active) inFlight = false

    DaemonBackend {
        id: client
        daemonName: "clip-daemon"
        expectedProtocol: ClipApi.protocol
        expectedVersion: ClipApi.version
        streams: [ClipApi.streams.operation]
        recoverProtocolErrors: true
        active: capture.active
        onResponseReceived: function (id, envelope, transportError) {
            if (id === "capture-screenshot")
                capture.finish(envelope, transportError);
        }
        onSendFailed: function (id, message) {
            if (id === "capture-screenshot")
                capture.reject(message);
        }
        onTransportFailed: function (message) {
            if (capture.inFlight)
                capture.reject(message);
        }
    }
}
