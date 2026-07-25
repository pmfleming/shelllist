import QtQuick
import "NmApi.js" as NmApi
import "NmApiClient.js" as Api
import "process"

Item {
    id: backend

    required property WifiController controller
    property var pending: ({})
    readonly property bool active: controller.uiActive
        || Object.keys(pending || ({})).length > 0
        || controller.connection.running
        || controller.prompt.open
    readonly property bool listRunning: isPending("networks")
    readonly property bool scanRunning: isPending("scan-start") || controller.scan.requestId.length > 0
    readonly property bool connectStarting: isPending("connect-start")
    readonly property bool nonConnectRunning: isPending("power") || isPending("disconnect") || isPending("profile") || isPending("advanced-load") || isPending("advanced-save") || isPending("advanced-secret") || isPending("secret-provide") || isPending("secret-cancel")
    readonly property bool running: connectStarting || nonConnectRunning || controller.connection.requestId.length > 0
    readonly property var responseHandlerById: ({
        "networks": function (value) { backend.handleNetworks(value); },
        "scan-start": function (value) { backend.handleScanStart(value); },
        "power": function (value) { controller.applyPowerResult(Api.apiData(value, "result") || ({})); },
        "connect-start": function (value) { backend.handleConnectStart(value); },
        "disconnect": function (value) { backend.handleDisconnect(value); },
        "advanced-load": function (value) { controller.advanced.applyProfile(Api.apiData(value, "result") || ({})); },
        "advanced-save": function (value) { backend.handleAdvancedSave(value); },
        "advanced-secret": function (value) { controller.advanced.applySecret(Api.apiData(value, "result") || ({})); },
        "profile": function (value) { backend.handleProfile(value); },
        "share": function (value) { controller.applyShareResponse(value, "Saved profile could not be shared"); },
        "secret-provide": function (value) { backend.handleSecretResponse(value); },
        "secret-cancel": function (value) { backend.handleSecretResponse(value); }
    })

    function isPending(id) { return !!pending[id]; }
    function setPending(id, value) {
        if (value)
            pending[id] = true;
        else
            delete pending[id];
        pending = Object.assign({}, pending);
    }

    function call(id, method, params) {
        if (isPending(id)) {
            console.warn("shelllist nm request rejected id=" + id + " reason=already-pending");
            return false;
        }
        setPending(id, true);
        console.info("shelllist nm request started id=" + id + " method=" + method);
        try {
            client.call(id, method, params);
            return true;
        } catch (error) {
            setPending(id, false);
            const message = "Could not send nm-daemon " + id + " request: " + error;
            console.error("shelllist nm request failed id=" + id + " stage=send error=" + error);
            controller.failCall(id, message);
            return false;
        }
    }

    function refreshNetworks(refreshCache) { return call("networks", NmApi.methods.wifi_networks, { cached: true, refresh_cache: !!refreshCache }); }
    function startScan() { return call("scan-start", NmApi.methods.wifi_scan, { timeout: 12, cache: true }); }
    function setPowered(enabled) { return call("power", NmApi.methods.wifi_setEnabled, { enabled: enabled }); }
    function connect(request) { return call("connect-start", NmApi.methods.wifi_connectTarget, request); }
    function disconnect() { return call("disconnect", NmApi.methods.wifi_disconnect, {}); }
    function profile(operation) {
        if (!operation || !operation.operation) {
            console.error("shelllist profile request rejected reason=missing-operation");
            controller.status = "Could not update the saved Wi-Fi profile: missing operation.";
            return false;
        }
        if (operation.operation === "forget")
            console.info("shelllist forget request=" + JSON.stringify(operation));
        return call("profile", NmApi.methods.wifi_profile_operation, operation);
    }
    function share(path) { return call("share", NmApi.methods.wifi_profile_operation, { operation: "share", path: path }); }
    function loadAdvancedProfile(path) { return call("advanced-load", NmApi.methods.wifi_profile_operation, { operation: "details", path: path }); }
    function saveAdvancedProfile(path, settings) { return call("advanced-save", NmApi.methods.wifi_profile_operation, { operation: "update", path: path, settings: settings }); }
    function revealAdvancedSecret(path) { return call("advanced-secret", NmApi.methods.wifi_profile_operation, { operation: "reveal-secret", path: path }); }
    function provideSecret(requestId, key, password, save) {
        const values = ({});
        values[key] = password;
        return call("secret-provide", NmApi.methods.wifi_secret_provide, { request_id: requestId, values: values, save: !!save, cancel: false });
    }
    function cancelSecret(requestId) { return call("secret-cancel", NmApi.methods.wifi_secret_provide, { request_id: requestId, cancel: true }); }
    function cancel(requestId) {
        if (!requestId)
            return false;
        try {
            console.info("shelllist nm cancellation requested request_id=" + requestId);
            client.cancel(requestId);
            return true;
        } catch (error) {
            console.error("shelllist nm cancellation failed request_id=" + requestId + " error=" + error);
            controller.status = "Could not cancel nm-daemon request " + requestId + ": " + error;
            return false;
        }
    }

    function handleNetworks(envelope) {
        const networks = Api.apiData(envelope, "networks") || [];
        if (!controller.scan.snapshotSeen) controller.applyNetworks(networks, true);
        controller.setBackgroundStatus(networks.length + " cached networks; scanning…");
    }

    function handleScanStart(envelope) {
        const result = Api.apiResult(envelope, "result") || ({});
        const requestId = result.request_id || "";
        if ((!controller.uiActive || !controller.powered) && requestId.length > 0) {
            console.info("shelllist wifi scan cancelled reason=" + (controller.uiActive ? "wifi-off" : "ui-hidden") + " request_id=" + requestId);
            cancel(requestId);
            return;
        }
        controller.scan.requestId = requestId;
        controller.setBackgroundStatus(result.message || "Wi-Fi scan started…");
    }

    function handleConnectStart(envelope) {
        const connect = Api.apiResult(envelope, "result") || ({});
        if (connect.status !== "error") {
            controller.connection.requestId = connect.request_id || "";
            controller.status = connect.message || ("Connecting to " + controller.connection.networkName + "…");
            return;
        }
        controller.connection.resetProgress();
        controller.connection.applyResult(connect, connect.message || "Connection failed to start");
    }

    function handleDisconnect(envelope) {
        const result = Api.apiData(envelope, "result") || ({});
        controller.status = result.message || "Disconnected Wi-Fi"; controller.refresh();
    }

    function handleAdvancedSave(envelope) {
        controller.advanced.applySave(Api.apiData(envelope, "result") || ({}));
        controller.invalidateShareAvailabilityCache(); controller.refresh();
    }

    function logForgetResult(result) {
        if (result.operation !== "forget")
            return;
        console.info("shelllist forget result request_id=" + (result.request_id || "")
            + " ssid=" + (result.ssid || "")
            + " status=" + (result.status || "unknown")
            + " disconnected=" + !!result.disconnected
            + " profiles_found=" + (result.profiles_found || 0)
            + " profiles_deleted=" + (result.deleted_profiles ? result.deleted_profiles.length : 0)
            + " profiles_failed=" + (result.failed_profiles ? result.failed_profiles.length : 0));
    }

    function handleProfile(envelope) {
        const result = Api.apiData(envelope, "result") || ({});
        logForgetResult(result); controller.status = result.message || "Saved profile updated";
        controller.invalidateShareAvailabilityCache(); controller.refresh();
    }

    function handleSecretResponse(envelope) {
        const result = Api.apiResult(envelope, "result") || ({});
        if (result.status === "error") controller.status = result.message || "Wi-Fi secret was not accepted";
    }

    function isSessionControl(id) { return id === "session-subscribe" || id.indexOf("cancel-") === 0 || id.indexOf("shutdown-") === 0; }

    function finish(id, envelope, transportError) {
        if (isSessionControl(id))
            return;
        setPending(id, false);
        if (transportError.length > 0) {
            console.error("shelllist nm request failed id=" + id + " stage=response error=" + transportError);
            controller.failCall(id, "nm-daemon request failed: " + transportError);
            return;
        }
        try {
            const handler = responseHandlerById[id];
            if (!handler)
                console.warn("shelllist nm response ignored id=" + id + " reason=no-handler");
            else
                handler(envelope);
            console.info("shelllist nm request completed id=" + id);
        } catch (error) {
            console.error("shelllist nm request failed id=" + id + " stage=parse error=" + error);
            controller.failCall(id, "Could not parse nm-daemon " + id + " response: " + error);
        }
        controller.maybeRunPendingRefresh();
    }

    function handleTransportFailure(message) {
        const lostRequestIds = Object.keys(pending || ({}));
        pending = ({});
        console.error("shelllist nm transport failed error=" + message
            + " lost_requests=" + (lostRequestIds.length > 0 ? lostRequestIds.join(",") : "none"));
        controller.handleTransportFailure(message, lostRequestIds);
    }

    function handleTransportReady() {
        console.info("shelllist nm transport ready");
        controller.handleTransportReady();
    }

    function portalArguments(context) {
        const args = [
            "shelllist-captive-portal", context.automatic ? "--automatic" : "--manual",
            "--trigger", context.trigger, "--ssid", context.ssid,
            "--identity", context.identity, "--connectivity", context.connectivity,
            "--request-id", context.requestId, "--workspace", context.workspaceId
        ];
        if (context.automatic)
            args.push("--episode", context.episode);
        if (context.fallback)
            args.push("--fallback");
        return args;
    }
    function startPortal(context) {
        try {
            console.info("shelllist portal helper started trigger=" + context.trigger + " request_id=" + context.requestId);
            portalProcess.exec(portalArguments(context));
        } catch (error) {
            console.error("shelllist portal helper failed stage=start error=" + error);
            controller.status = "Could not start captive portal browser: " + error;
        }
    }
    function openPortal(context) {
        if (portalProcess.running) {
            console.info("shelllist portal decision=helper-busy trigger=" + context.trigger + " request_id=" + context.requestId);
            return;
        }
        startPortal(context);
    }

    NmDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) { backend.controller.handleDaemonEvent(event); }
        onTransportFailed: function (message) { backend.handleTransportFailure(message); }
        onReadyChanged: if (ready) backend.handleTransportReady()
    }

    CommandProcess {
        id: portalProcess
        stderrWaitForEnd: false
        onFinished: function (exitCode, outputText, errorText) {
            if (exitCode !== 0) {
                const detail = errorText.length > 0 ? errorText : ("exit " + exitCode);
                console.error("shelllist portal helper failed stage=exit error=" + detail);
                backend.controller.status = "Could not open captive portal browser: " + detail;
            } else {
                console.info("shelllist portal helper completed");
            }
        }
    }
}
