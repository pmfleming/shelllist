import QtQuick
import Shelllist.Core as Core

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
        if (!backend.call("publish-text", "clipboard.selection.publishText", { text: text })) {
            inFlight = false;
            return false;
        }
        return true;
    }

    function complete(envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "clip-api", 1, "clip-daemon", "Clipboard publication failed");
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
        expectedProtocol: "clip-api"
        expectedVersion: 1
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
