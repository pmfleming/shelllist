import QtQuick
import Shelllist.Io as Io

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
    function unavailable(): void {
        available = false;
        revision = -1; // A new daemon lifetime starts a new revision sequence.
    }
    onActiveChanged: if (!active) {
        unavailable();
        reduced = false;
    }

    Io.BarProjectionBackend {
        objectName: "compositorMotionBackend"
        active: client.active
        projection: "compositor"
        failureMessage: "Compositor preference unavailable"
        onReceived: value => client.apply(value)
        onReadFailed: client.available = false
        onTransportFailed: client.unavailable()
    }
}
