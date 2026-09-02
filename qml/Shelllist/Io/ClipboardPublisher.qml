import QtQuick
import "../../../clipboard/ClipApi.js" as ClipApi

Item {
    id: publisher

    property bool inFlight: false
    property string successMessage: "Copied to the clipboard"

    signal finished(bool succeeded, string message)

    function publishText(text: string, message: string): bool {
        if (inFlight || !text.length)
            return false;
        inFlight = true;
        successMessage = message || "Copied to the clipboard";
        if (!backend.call("publish-text", ClipApi.methods.selectionPublishText, { text: text })) {
            inFlight = false;
            return false;
        }
        return true;
    }

    function complete(envelope: var, transportError: string): void {
        const error = backend.responseError(envelope, transportError,
            "Clipboard publication failed");
        inFlight = false;
        if (error.length > 0) {
            finished(false, error);
            return;
        }
        finished(true, successMessage);
    }

    DaemonBackend {
        id: backend
        daemonName: "clip-daemon"
        expectedProtocol: ClipApi.protocol
        expectedVersion: ClipApi.version
        streams: []
        recoverProtocolErrors: true
        active: publisher.inFlight
        onResponseReceived: function (id, envelope, transportError) {
            if (id === "publish-text")
                publisher.complete(envelope, transportError);
        }
        onSendFailed: function (id, message) {
            if (id === "publish-text") {
                publisher.inFlight = false;
                publisher.finished(false, message);
            }
        }
        onTransportFailed: function (message) {
            if (publisher.inFlight) {
                publisher.inFlight = false;
                publisher.finished(false, message);
            }
        }
    }
}
