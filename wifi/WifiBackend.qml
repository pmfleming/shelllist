import QtQuick
import "NmApi.js" as NmApi
import "Wifi.js" as Wifi
import "."

Item {
    id: backend

    required property var controller
    property var pending: ({})
    readonly property bool active: controller.uiActive || controller.connectRunning || controller.prompt.open
    readonly property bool listRunning: isPending("networks")
    readonly property bool scanRunning: isPending("scan-start") || controller.activeScanRequestId.length > 0
    readonly property bool connectStarting: isPending("connect-start")
    readonly property bool nonConnectRunning: isPending("disconnect") || isPending("profile") || isPending("secret-provide") || isPending("secret-cancel")
    readonly property bool running: connectStarting || nonConnectRunning || controller.activeConnectRequestId.length > 0

    function isPending(id) { return !!pending[id]; }
    function setPending(id, value) {
        if (value)
            pending[id] = true;
        else
            delete pending[id];
        pending = Object.assign({}, pending);
    }

    function call(id, method, params) {
        if (isPending(id))
            return false;
        setPending(id, true);
        client.call(id, method, params);
        return true;
    }

    function refreshNetworks(refreshCache) { return call("networks", NmApi.methods.wifi_networks, { cached: true, refresh_cache: !!refreshCache }); }
    function startScan() { return call("scan-start", NmApi.methods.wifi_scan, { timeout: 12, cache: true }); }
    function connect(request) { return call("connect-start", NmApi.methods.wifi_connectTarget, request); }
    function disconnect() { return call("disconnect", NmApi.methods.wifi_disconnect, {}); }
    function profile(operation) { return call("profile", NmApi.methods.wifi_profile_operation, operation); }
    function share(path) { return call("share", NmApi.methods.wifi_profile_operation, { operation: "share", path: path }); }
    function provideSecret(requestId, key, password, save) {
        const values = ({});
        values[key] = password;
        return call("secret-provide", NmApi.methods.wifi_secret_provide, { request_id: requestId, values: values, save: !!save, cancel: false });
    }
    function cancelSecret(requestId) { return call("secret-cancel", NmApi.methods.wifi_secret_provide, { request_id: requestId, cancel: true }); }
    function cancel(requestId) { client.cancel(requestId); }

    function finish(id, envelope, transportError) {
        if (id !== "session-subscribe" && id.indexOf("cancel-") !== 0 && id.indexOf("shutdown-") !== 0)
            setPending(id, false);
        if (id === "session-subscribe" || id.indexOf("cancel-") === 0 || id.indexOf("shutdown-") === 0)
            return;
        if (transportError.length > 0)
            return controller.failCall(id, "nm-daemon request failed: " + transportError);
        try {
            if (id === "networks") {
                const updated = Wifi.apiData(envelope, "networks") || [];
                if (!controller.scanSnapshotSeen)
                    controller.applyNetworks(updated, true);
                controller.setBackgroundStatus(updated.length + " cached networks; scanning…");
            } else if (id === "scan-start") {
                const scan = Wifi.apiResult(envelope, "result") || ({});
                controller.activeScanRequestId = scan.request_id || "";
                controller.setBackgroundStatus(scan.message || "Wi-Fi scan started…");
            } else if (id === "connect-start") {
                const connect = Wifi.apiResult(envelope, "result") || ({});
                if (connect.status === "error") {
                    controller.resetConnectProgress();
                    controller.applyConnectResult(connect, connect.message || "Connection failed to start");
                } else {
                    controller.activeConnectRequestId = connect.request_id || "";
                    controller.status = connect.message || ("Connecting to " + controller.connectingNetworkName + "…");
                }
            } else if (id === "disconnect") {
                const disconnected = Wifi.apiData(envelope, "result") || ({});
                controller.status = disconnected.message || "Disconnected Wi-Fi";
                controller.refresh();
            } else if (id === "profile") {
                const profileResult = Wifi.apiData(envelope, "result") || ({});
                controller.status = profileResult.message || "Saved profile updated";
                controller.refresh();
            } else if (id === "share") {
                controller.applyShareResponse(envelope, "Saved profile could not be shared");
            } else if (id === "secret-provide" || id === "secret-cancel") {
                const secret = Wifi.apiResult(envelope, "result") || ({});
                if (secret.status === "error")
                    controller.status = secret.message || "Wi-Fi secret was not accepted";
            }
        } catch (error) {
            controller.failCall(id, "Could not parse nm-daemon " + id + " response: " + error);
        }
        controller.maybeRunPendingRefresh();
    }

    function openPortal() {
        if (!portalProcess.running)
            portalProcess.exec(["shelllist-captive-portal"]);
    }

    NmDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) { backend.controller.handleDaemonEvent(event); }
        onTransportFailed: function (message) { backend.controller.status = message; }
    }

    CommandProcess {
        id: portalProcess
        stderrWaitForEnd: false
        onFinished: function (exitCode, outputText, errorText) {
            if (exitCode !== 0 && errorText.length > 0)
                backend.controller.status = "Could not open captive portal browser: " + errorText;
        }
    }
}
