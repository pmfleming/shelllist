import QtQuick
import Shelllist.Io as Io
import "NmApi.js" as NmApi
import "NmApiClient.js" as Api
import "process"

Io.DaemonBackend {
    id: backend

    required property WifiController controller
    daemonName: "nm-daemon"
    streams: NmApi.subscribedStreams
    recoverProtocolErrors: false
    active: controller.statusMonitorActive || controller.uiActive || requestRunning
        || controller.connection.running || controller.promptActive
    readonly property bool listRunning: isPending("networks")
    readonly property bool scanRunning: isPending("scan-start") || controller.scan.requestId.length > 0
    readonly property bool connectStarting: isPending("connect-start")
    readonly property bool nonConnectRunning: isPending("power") || isPending("disconnect")
        || isPending("profile") || isPending("advanced-load") || isPending("advanced-save")
        || isPending("advanced-secret") || isPending("band-status") || isPending("band-set")
        || isPending("secret-provide") || isPending("secret-cancel")
        || isPending("qr-parse") || isPending("qr-connect")
        || isPending("hotspot-capabilities") || isPending("hotspot-status")
        || isPending("hotspot-start") || isPending("hotspot-stop")
        || isPending("vpn-list") || isPending("vpn-status")
        || isPending("vpn-connect") || isPending("vpn-disconnect")
        || isPending("inventory") || isPending("network-status")
        || isPending("activate-profile") || isPending("deactivate-connection")
        || isPending("statistics-watch")
    readonly property bool running: connectStarting || nonConnectRunning || controller.connection.requestId.length > 0
    readonly property var responseHandlerById: ({
        "networks": function (value) { backend.handleNetworks(value); },
        "band-status": function (value) { controller.applyBandStatus(Api.apiData(value, "band") || ({})); },
        "band-set": function (value) { controller.applyBandStart(Api.apiData(value, "result") || ({})); },
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
        "secret-cancel": function (value) { backend.handleSecretResponse(value); },
        "qr-parse": function (value) { backend.handleQrParse(value); },
        "qr-connect": function (value) { backend.handleConnectStart(value); },
        "hotspot-capabilities": function (value) { controller.hotspot.applyCapabilities(Api.apiData(value, "hotspot") || null); },
        "hotspot-status": function (value) { controller.hotspot.applyStatus(Api.apiData(value, "hotspot") || null); },
        "hotspot-start": function (value) { controller.hotspot.applyStart(Api.apiResult(value, "result") || ({})); },
        "hotspot-stop": function (value) { controller.hotspot.applyStop(Api.apiData(value, "result") || ({})); },
        "vpn-list": function (value) { controller.vpn.applyProfiles(Api.apiData(value, "vpns") || []); },
        "vpn-status": function (value) { controller.vpn.applyStatus(Api.apiData(value, "vpn") || null); },
        "vpn-connect": function (value) { controller.vpn.applyConnectStart(Api.apiResult(value, "result") || ({})); },
        "vpn-disconnect": function (value) { controller.vpn.applyDisconnect(Api.apiData(value, "result") || ({})); },
        "inventory": function (value) { controller.inventory.applyInventory(Api.apiData(value, "inventory") || null); },
        "network-status": function (value) { controller.inventory.applyNetworkState(Api.apiData(value, "network") || null); },
        "activate-profile": function (value) { controller.inventory.applyActivation(Api.apiData(value, "result") || ({})); },
        "deactivate-connection": function (value) { controller.inventory.applyDeactivation(Api.apiData(value, "result") || ({})); },
        "statistics-watch": function (value) { controller.statistics.applyStart(Api.apiResult(value, "result") || ({})); }
    })

    function refreshNetworks(refreshCache) { return call("networks", NmApi.methods.wifi_networks, { cached: true, refresh_cache: !!refreshCache }); }
    function loadBandStatus(path) { return call("band-status", NmApi.methods.wifi_band_status, { path: path }); }
    function setBand(path, band) { return call("band-set", NmApi.methods.wifi_band_set, { path: path, band: band }); }
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
    function provideSecrets(requestId, values, save) {
        return call("secret-provide", NmApi.methods.wifi_secret_provide,
            { request_id: requestId, values: values || ({}), save: !!save, cancel: false });
    }
    function cancelSecret(requestId) { return call("secret-cancel", NmApi.methods.wifi_secret_provide, { request_id: requestId, cancel: true }); }

    // A scanned QR payload carries a passphrase. It is passed straight to the
    // daemon over the protected transport and never logged here.
    function parseQr(payload) { return call("qr-parse", NmApi.methods.wifi_qr_parse, { payload: payload }); }
    function connectQr(payload, ifname) {
        return call("qr-connect", NmApi.methods.wifi_qr_connect,
            ifname ? { payload: payload, ifname: ifname } : { payload: payload });
    }

    function loadHotspotCapabilities() { return call("hotspot-capabilities", NmApi.methods.hotspot_capabilities, {}); }
    function loadHotspotStatus() { return call("hotspot-status", NmApi.methods.hotspot_status, {}); }
    function startHotspot(options) { return call("hotspot-start", NmApi.methods.hotspot_start, options || ({})); }
    function stopHotspot() { return call("hotspot-stop", NmApi.methods.hotspot_stop, {}); }

    function loadVpnProfiles() { return call("vpn-list", NmApi.methods.vpn_list, {}); }
    function loadVpnStatus() { return call("vpn-status", NmApi.methods.vpn_status, {}); }
    function connectVpn(request) { return call("vpn-connect", NmApi.methods.vpn_connect, request || ({})); }
    function disconnectVpn(request) { return call("vpn-disconnect", NmApi.methods.vpn_disconnect, request || ({})); }

    function loadInventory() { return call("inventory", NmApi.methods.network_inventory, {}); }
    function loadNetworkState() { return call("network-status", NmApi.methods.network_status, {}); }
    function activateProfile(request) { return call("activate-profile", NmApi.methods.network_activateProfile, request || ({})); }
    function deactivateConnection(request) { return call("deactivate-connection", NmApi.methods.network_deactivate, request || ({})); }
    function watchStatistics(request) { return call("statistics-watch", NmApi.methods.network_statistics_watch, request || ({})); }

    function handleQrParse(envelope) {
        controller.applyScannedQr(Api.apiData(envelope, "qr") || ({}));
    }
    function handleNetworks(envelope) {
        const data = Api.apiPayload(envelope);
        if (!envelope.ok)
            throw new Error(Api.apiErrorMessage(envelope));
        const networks = data.networks || [];
        const snapshot = data.snapshot || null;
        if (!controller.scan.snapshotSeen)
            controller.applyNetworks(networks, true, snapshot);
        const stale = snapshot && snapshot.stale ? "stale " : "";
        controller.setBackgroundStatus(networks.length + " " + stale + "cached networks; scanning…");
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

    function finish(id, envelope, transportError) {
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
        if (context.checkUri && context.checkUri.length > 0)
            args.push("--check-uri", context.checkUri);
        if (context.primaryConnection && context.primaryConnection.length > 0)
            args.push("--primary-connection", context.primaryConnection);
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

    onResponseReceived: function (id, envelope, transportError) { finish(id, envelope, transportError); }
    onEventReceived: function (event) { controller.handleDaemonEvent(event); }
    onSendFailed: function (id, message) { controller.failCall(id, message); }
    onTransportFailed: function (message, lostRequestIds) {
        console.error("shelllist nm transport failed error=" + message
            + " lost_requests=" + (lostRequestIds.length > 0 ? lostRequestIds.join(",") : "none"));
        controller.handleTransportFailure(message, lostRequestIds);
    }
    onTransportReady: handleTransportReady()

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
