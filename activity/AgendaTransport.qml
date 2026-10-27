import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

// Only the existing shared daemon bridge owns sockets and reconnects.
Io.DaemonBackend {
    id: transport
    daemonName: "bar-daemon"
    expectedProtocol: ActivityApi.protocol
    expectedVersion: ActivityApi.version
    streams: [ActivityApi.streams.activity, ActivityApi.streams.timezone]
    active: false
    signal completed(string id, var data, string error)
    onResponseReceived: function(id, envelope, transportError) {
        const error = responseError(envelope, transportError, qsTr("Agenda request failed"));
        completed(id, error ? null : envelope.data, error);
    }
    onSendFailed: function(id, message) { completed(id, null, message); }
}
