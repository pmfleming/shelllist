import QtQuick
import Shelllist.Io as Io
import Shelllist.Launcher as Launcher

Io.DaemonBackend {
    id: backend
    required property UpdateController controller
    property string request: ""
    property bool refreshPending: false
    property bool forcePending: false
    property int observationGeneration: 0
    property int requestGeneration: 0
    daemonName: "app-daemon"
    expectedProtocol: Launcher.AppProtocol.protocol
    expectedVersion: Launcher.AppProtocol.version
    streams: ["applications.catalog.changed"]
    active: controller.uiActive
    validateRequest: Launcher.AppProtocol.requestError
    validateEvent: Launcher.AppProtocol.eventError
    onActiveChanged: if (!active) { request = ""; refreshPending = false; forcePending = false; }
    function refresh(force: bool): void {
        if (!active || !ready) return;
        if (request) { refreshPending = true; forcePending = forcePending || force; return; }
        request = nextRequestId("software-catalog");
        requestGeneration = observationGeneration;
        call(request, "applications.catalog", {refresh: force});
    }
    function finish(id: string, envelope: var, error: string): void {
        if (!request || id !== request || !active) return;
        request = "";
        const failure = responseError(envelope, error, qsTr("Application catalog unavailable"))
            || Launcher.AppProtocol.responseError("applications.catalog", envelope);
        if (requestGeneration === observationGeneration) {
            controller.catalogError = failure;
            if (!failure) controller.applicationCatalog = envelope.data.catalog;
        } else refreshPending = true;
        if (refreshPending) {
            const force = forcePending; refreshPending = false; forcePending = false;
            Qt.callLater(function() { backend.refresh(force); });
        }
    }
    onTransportReady: refresh(false)
    onResponseReceived: function(id, envelope, error) { finish(id, envelope, error); }
    onSendFailed: function(id, error) { finish(id, null, error); }
    onTransportFailed: function(error) { observationGeneration++; request = ""; refreshPending = false; forcePending = false; controller.catalogError = error; }
    onEventReceived: function(event) {
        if (event.event === "changed" || event.event === "subscribed") { observationGeneration++; refresh(false); }
    }
    onEventGapDetected: { observationGeneration++; refresh(false); }
}
