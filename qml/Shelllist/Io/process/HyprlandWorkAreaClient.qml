import QtQuick
import Shelllist.Io as Io
import "../../Bar/BarProtocol.generated.js" as Protocol

Item {
    id: client

    property bool active: false
    property string monitorName: ""
    property var snapshot: null
    property bool ready: false
    readonly property var insets: snapshot && snapshot.available ? (snapshot.monitors[monitorName] || null) : null

    function apply(value: var): void {
        if (!active || !value)
            return;
        snapshot = value;
        if (value.available || value.error)
            ready = true;
    }
    function refresh(): void {
        if (active)
            backend.call("work-area-snapshot", Protocol.methods["bar.snapshot"], {});
    }
    function scheduleRefresh(): void {
        if (active)
            Qt.callLater(refresh);
    }
    function unavailable(): void {
        snapshot = null;
        ready = true;
    }
    onActiveChanged: {
        snapshot = null;
        ready = false;
    }

    // View-loading deadline only; system polling and parsing live in bar-daemon.
    Timer {
        interval: 2500
        running: client.active && !client.ready
        onTriggered: client.ready = true
    }
    Io.DaemonBackend {
        id: backend
        objectName: "workAreaBackend"
        active: client.active
        daemonName: "bar-daemon"
        expectedProtocol: Protocol.protocol
        expectedVersion: Protocol.version
        streams: [Protocol.streams["workarea.changed"]]
        onTransportReady: client.refresh()
        onTransportFailed: client.unavailable()
        onResponseReceived: function (id, envelope, transportError) {
            if (responseError(envelope, transportError, "Work area unavailable"))
                client.unavailable();
            else
                client.apply(envelope.data && envelope.data.snapshot ? envelope.data.snapshot.workarea : null);
        }
        onEventGapDetected: client.refresh()
        onEventReceived: function (event) {
            if (event.stream === Protocol.streams["workarea.changed"])
                client.apply(event.data);
        }
    }
}
