import QtQuick
import Shelllist.Io as Io
import "../../Bar/BarProtocol.generated.js" as Protocol

Item {
    id: client
    property bool active: false
    property bool reduced: false
    property bool available: false
    property double revision: -1

    function apply(value: var): void {
        if (!active || !value || typeof value.revision !== "number" || !Number.isSafeInteger(value.revision) || value.revision < 0 || value.revision < revision)
            return;
        revision = value.revision;
        available = value.available === true && typeof value.animations_enabled === "boolean";
        // The daemon retains its last valid observation on errors. Unknown
        // data, disconnects and restarts must not enable previously disabled
        // motion. No compositor parsing or subprocess fallback lives here.
        if (typeof value.animations_enabled === "boolean")
            reduced = !value.animations_enabled;
    }
    function refresh(): void {
        if (active)
            backend.call("compositor-snapshot", Protocol.methods["bar.snapshot"], {});
    }
    function unavailable(): void {
        available = false;
        revision = -1; // A new daemon lifetime starts a new revision sequence.
    }
    onActiveChanged: if (!active) {
        unavailable();
        reduced = false;
    }

    Io.DaemonBackend {
        id: backend
        objectName: "compositorMotionBackend"
        active: client.active
        daemonName: "bar-daemon"
        expectedProtocol: Protocol.protocol
        expectedVersion: Protocol.version
        streams: [Protocol.streams["compositor.changed"]]
        onTransportReady: client.refresh()
        onTransportFailed: client.unavailable()
        onResponseReceived: function (id, envelope, transportError) {
            if (responseError(envelope, transportError, "Compositor preference unavailable"))
                client.available = false;
            else
                client.apply((envelope.data && envelope.data.snapshot || {}).compositor);
        }
        onEventGapDetected: client.refresh()
        onEventReceived: function (event) {
            if (event.stream === Protocol.streams["compositor.changed"])
                client.apply(event.data);
        }
    }
}
