import Shelllist.Io as Io
import Shelllist.Launcher as Launcher

Io.DaemonBackend {
    required property var controller
    daemonName: "app-daemon"
    expectedProtocol: Launcher.AppApi.protocol
    expectedVersion: Launcher.AppApi.version
    streams: []
    active: controller.uiActive

    function overview(period: string, sinceMs: double): bool {
        return call(nextRequestId("battery-energy-" + period),
            Launcher.AppApi.methods.energyOverview, { since_ms: sinceMs, limit: 12 });
    }

    onResponseReceived: function (id, envelope, transportError) {
        const error = responseError(envelope, transportError,
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
