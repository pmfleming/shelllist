import QtQuick
import "NmApiClient.js" as Api

// Wi-Fi hotspot lifecycle. Credentials only ever travel over the daemon's
// protected transport, and the generated passphrase is held for display only
// while the hotspot page is open.
Item {
    required property WifiController controller
    required property WifiBackend backend

    property var capabilities: null
    property var status: null
    property string requestId: ""
    // Set only by a start this session; the daemon never hands a running
    // hotspot's secret back.
    property string passphrase: ""
    property string qrPayload: ""

    readonly property bool active: !!(status && status.active)
    readonly property bool supported: !!(capabilities && capabilities.supported)
    readonly property string unsupportedReason: capabilities && capabilities.unsupported_reason
        ? capabilities.unsupported_reason : ""
    readonly property string unavailableMessage: capabilities && !capabilities.supported
        ? (capabilities.message || "A hotspot cannot be started") : ""
    readonly property bool starting: requestId.length > 0 || backend.isPending("hotspot-start")
    readonly property bool busy: starting || backend.isPending("hotspot-stop")

    function refresh() {
        backend.loadHotspotCapabilities();
        backend.loadHotspotStatus();
    }

    function start(options) {
        if (!supported) {
            controller.status = unavailableMessage;
            return false;
        }
        forgetCredentials();
        return backend.startHotspot(options || ({}));
    }

    function stop() {
        if (requestId.length > 0)
            return cancel();
        return backend.stopHotspot();
    }

    function cancel() {
        if (requestId.length === 0)
            return false;
        const cancelled = backend.cancel(requestId);
        if (!cancelled)
            console.warn("shelllist hotspot cancellation failed request_id=" + requestId);
        return cancelled;
    }

    // Credentials are dropped as soon as they are no longer being shown.
    function forgetCredentials() {
        passphrase = "";
        qrPayload = "";
    }

    function applyCapabilities(value) { capabilities = value || null; }
    function applyStatus(value) {
        status = value || null;
        if (!active)
            forgetCredentials();
    }
    function applyStart(result) {
        requestId = (result && result.request_id) || "";
        controller.status = (result && result.message) || "Starting hotspot…";
    }
    function applyStop(result) {
        forgetCredentials();
        controller.status = (result && result.message) || "Hotspot stopped";
        refresh();
    }

    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId))
            return;
        if (event.event === "progress") {
            controller.status = "Starting hotspot…";
            return;
        }
        if (!Api.isTerminalEvent(event) && event.event !== "succeeded")
            return;
        requestId = "";
        if (event.event === "succeeded")
            applySucceeded(event.result || ({}));
        else
            controller.status = event.message || "Hotspot could not be started";
        refresh();
    }

    function applySucceeded(result) {
        const detail = result.hotspot || ({});
        status = detail;
        passphrase = result.passphrase || "";
        qrPayload = detail.share ? (detail.share.qr_payload || "") : "";
        controller.status = result.message || "Hotspot is running";
    }
}
