import QtQuick
import "../Bar/BarProtocol.generated.js" as Protocol

// Qt supplies desktop preferences only. All HCT, tones and semantic roles are
// computed by bar-daemon. Preview clients never publish to the shared stream.
BarDaemonBackend {
    property color seedColor: "#6750a4"
    property bool dark: false
    property bool publishTheme: false
    property var roles: null
    property string latestRequest: ""
    daemonName: "bar-daemon"
    expectedProtocol: Protocol.protocol
    expectedVersion: Protocol.version
    streams: publishTheme ? [Protocol.streams["theme.changed"]] : []
    validateRequest: Protocol.requestError
    validateEvent: Protocol.eventError

    function resolve(): void {
        if (!active || !ready)
            return;
        latestRequest = nextRequestId("theme");
        call(latestRequest, publishTheme ? "theme.configure" : "theme.resolve", {
            seed: Qt.rgba(seedColor.r, seedColor.g, seedColor.b, 1).toString(), dark: dark
        });
    }
    function accept(value: var): void {
        // Reject partial/malformed maps atomically; retain the last good theme.
        if (Protocol.schemaError(Protocol.contracts["theme.resolve"].result_schema, value).length === 0)
            roles = value;
    }
    onSeedColorChanged: Qt.callLater(resolve)
    onDarkChanged: Qt.callLater(resolve)
    onPublishThemeChanged: Qt.callLater(resolve)
    onTransportReady: resolve()
    onResponseReceived: function (id, envelope, transportError) {
        if (responseError(envelope, transportError, "Theme generation failed"))
            return;
        if (id === latestRequest)
            accept(envelope.data.theme || envelope.data.snapshot?.theme);
        else if (publishTheme && envelope.data.snapshot)
            accept(envelope.data.snapshot.theme);
    }
    onEventReceived: function (event) {
        if (publishTheme && event.stream === Protocol.streams["theme.changed"])
            accept(event.data);
    }
}
