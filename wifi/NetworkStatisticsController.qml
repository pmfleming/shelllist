import QtQuick
import "NmApiClient.js" as Api

// Owner-scoped aggregate transfer counters for one NetworkManager device.
// Samples contain byte totals and rates only; no packet or destination data.
Item {
    required property WifiController controller
    required property WifiBackend backend

    property string requestId: ""
    property string devicePath: ""
    property string deviceIface: ""
    property int intervalMs: 1000
    property var sample: null
    property string error: ""

    readonly property bool watching: requestId.length > 0
    readonly property bool busy: watching || backend.isPending("statistics-watch")

    function start(device, requestedIntervalMs) {
        if (busy) {
            controller.status = "Network statistics are already being watched.";
            return false;
        }
        const selector = typeof device === "string"
            ? device
            : ((device && (device.path || device.interface)) || "");
        const requested = requestedIntervalMs || 1000;
        const params = { interval_ms: requested };
        if (selector.length > 0)
            params.device = selector;
        sample = null;
        error = "";
        return backend.watchStatistics(params);
    }

    function stop() {
        if (requestId.length === 0)
            return false;
        return backend.cancel(requestId);
    }

    function applyStart(result) {
        if (!result || result.status === "error") {
            error = (result && result.message) || "Network statistics could not be started";
            controller.status = error;
            return;
        }
        requestId = result.request_id || "";
        devicePath = result.device_path || "";
        deviceIface = result.device_iface || "";
        intervalMs = result.interval_ms || 1000;
        controller.status = result.message || "Watching network statistics…";
    }

    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId))
            return;
        if (event.event === "sample") {
            sample = event.statistics || null;
            return;
        }
        if (event.event !== "failed" && event.event !== "cancelled")
            return;
        const message = event.message || (event.event === "failed"
            ? "Network statistics stopped after an error"
            : "Network statistics stopped");
        if (event.event === "failed")
            error = message;
        clear();
        controller.status = message;
    }

    function clear() {
        requestId = "";
        devicePath = "";
        deviceIface = "";
        sample = null;
    }

    function handleEventGap() {
        error = "Some network statistics samples were missed; live sampling continues.";
        controller.status = error;
    }

    function handleTransportFailure() {
        if (watching || backend.isPending("statistics-watch"))
            error = "Network statistics stopped because the daemon connection was lost.";
        clear();
    }
}
