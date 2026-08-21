import Shelllist.Core as Core
import Shelllist.Io as Io
// QML loads this file through qml/Shelllist/Battery, so use the module path's
// case-sensitive Launcher sibling rather than the source-tree directory name.
import "../Launcher/AppApi.js" as AppApi

Io.DaemonBackend {
    id: backend

    required property var controller
    daemonName: "app-daemon"
    streams: []
    active: controller.uiActive
    property int sequence: 0

    function overview(period: string, sinceMs: double): bool {
        sequence += 1;
        return call("battery-energy-" + period + "-" + sequence,
            AppApi.methods.energyOverview, { since_ms: sinceMs, limit: 12 });
    }

    onResponseReceived: function (id, envelope, transportError) {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            AppApi.protocol, AppApi.version, daemonName,
            "Application energy history is unavailable");
        if (error.length > 0) {
            controller.energyOverviewFailed(id, error);
            return;
        }
        controller.applyEnergyOverview(id,
            (envelope.data || ({})).energy_overview || ({}));
    }
    onSendFailed: function (id, message) {
        controller.energyOverviewFailed(id, message);
    }
    onTransportFailed: function (message) {
        controller.energyTransportFailed(message);
    }
    onActiveChanged: if (!active) pending = ({})
}
