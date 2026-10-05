import QtQuick
import Shelllist.Io as Io

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
    function scheduleRefresh(): void {
        if (active)
            Qt.callLater(backend.refresh);
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
    Io.BarProjectionBackend {
        id: backend
        objectName: "workAreaBackend"
        active: client.active
        projection: "workarea"
        snapshotId: "work-area-snapshot"
        failureMessage: "Work area unavailable"
        onReceived: value => client.apply(value)
        onReadFailed: client.unavailable()
        onTransportFailed: client.unavailable()
    }
}
