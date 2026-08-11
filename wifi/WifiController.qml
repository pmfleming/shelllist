import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api
import "process"
import "NmApi.js" as NmApi
import "."
import Shelllist.Io as Io
import Shelllist.Ui

ProviderChooserController {
    id: wifi

    required property WifiPromptController prompt
    provider: WifiProvider { id: wifiProvider; controller: wifi }

    property var activeStatus: null
    property string status
    readonly property var radios: activeStatus && activeStatus.radios ? activeStatus.radios : ({
        wireless_enabled: !activeStatus || activeStatus.enabled !== false,
        wireless_hardware_enabled: true,
        wireless_available: true
    })
    readonly property bool powered: radios.wireless_enabled !== false
        && radios.wireless_hardware_enabled !== false
    property double statusHoldUntil: 0
    readonly property WifiBackend backend: services.backend
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property bool promptActive: prompt.open || prompt.credentialOpen || qr.open
    readonly property bool actionInFlight: backend.running || screenshotInFlight
    readonly property string detailsTab: advanced.open ? advanced.section : "network"
    readonly property bool scanInFlight: scan.running
    readonly property var detailResult: selectedResult
    readonly property var detailAp: detailResult ? detailResult.payload : ({})
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property ShareAvailabilityController shareController: services.share
    readonly property WifiProvider providerModel: wifiProvider
    readonly property WifiConnectPolicy connectPolicy: services.policy
    navigationBlocked: promptActive || !powered
    readonly property WifiAdvancedController advanced: services.advanced
    readonly property WifiConnectionController connection: services.connection
    readonly property WifiNetworkActions actions: services.actions
    readonly property WifiScanController scan: services.scan
    readonly property WifiQrService qr: qrController
    readonly property var daemonEventHandlerByStream: {
        const handlers = ({});
        handlers[NmApi.streams.wifi_status] = function (event) { wifi.applyStatusEvent(event); };
        handlers[NmApi.streams.network_connectivity] = function (event) { connection.applyConnectivityEvent(event); };
        handlers[NmApi.streams.wifi_scan] = function (event) { scan.handleStream(event); };
        handlers[NmApi.streams.wifi_connect] = function (event) { connection.handleEvent(event); };
        handlers[NmApi.streams.wifi_secret] = function (event) { wifi.handleSecretEvent(event); };
        return handlers;
    }

    signal advancedSectionLeaving(string section)

    function activeAccessPoint() { return activeStatus ? (activeStatus.access_point || activeStatus.network || null) : null; }
    function activeNetworkKey() { return activeStatus && activeStatus.network ? (activeStatus.network.key || "") : ""; }
    function networkName(ap) { return Presentation.networkName(ap); }
    function isActive(ap) { return !!(ap && ap.active); }
    function profileFor(ap) { return Flow.profileForAccessPoint(ap); }
    function selectDetailsTab(tab) {
        if (tab === "network")
            advanced.closeSettings();
        else
            advanced.selectSection(tab);
    }

    function cycleDetailsTab() {
        if (!detailsOpen)
            return;
        const tabs = profileFor(detailAp) ? ["network", "security", "hardware"] : ["network"];
        const index = Math.max(0, tabs.indexOf(detailsTab));
        selectDetailsTab(tabs[(index + 1) % tabs.length]);
    }


    function invalidateShareAvailabilityCache() { services.share.invalidate(); }
    function shareSelected() {
        if (!services.share.canShareSelected()) {
            status = services.share.status;
            return;
        }
        qr.show(services.share.payload, networkName(detailAp));
    }
    function launchQrScanner() { return qr.launchScanner(); }
    function applyShareResponse(response, errorText) { services.share.applyResponse(response, errorText); }
    function statusIsHeld() { return Date.now() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = Date.now() + milliseconds; }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scan.activate();
        connection.activate();
    }

    function deactivateUi() {
        if (promptActive)
            cancelPrompt("popover-hidden");
        deactivateUiState();
        scan.deactivate();
        connection.deactivate();
    }

    function cancelPrompt(reason) {
        if (qr.open) {
            qr.close();
            return true;
        }
        if (!promptActive)
            return true;
        const mode = prompt.credentialOpen ? prompt.credentialMode : prompt.mode;
        const requestId = prompt.secretRequestId;
        let cancelled = true;
        if (mode === "daemon-secret" && requestId.length > 0)
            cancelled = connection.cancelSecret(requestId);
        prompt.cancel();
        console.info("shelllist wifi prompt closed mode=" + mode + " reason=" + (reason || "user")
            + " daemon_cancelled=" + cancelled);
        if (!cancelled)
            status = "Could not cancel the pending Wi-Fi secret request.";
        return cancelled;
    }

    function handleTransportFailure(message, lostRequestIds) {
        const lost = lostRequestIds || [];
        scan.handleTransportFailure();
        connection.handleTransportFailure();
        lost.forEach(function (id) {
            advanced.failCall(id, "nm-daemon transport failed before " + id + " completed: " + message);
        });
        if (lost.indexOf("share") >= 0)
            services.share.fail(message);
        if (promptActive && (prompt.mode === "daemon-secret" || prompt.credentialMode === "daemon-secret")) {
            console.warn("shelllist wifi daemon secret prompt discarded reason=transport-failure request_id=" + prompt.secretRequestId);
            prompt.cancel();
        }
        status = message + (lost.length > 0 ? " Lost requests: " + lost.join(", ") + "." : "");
    }

    function handleTransportReady() {
        if (uiActive)
            scan.maybeRefresh();
    }

    function refresh() { scan.refresh(); }
    function captureScreenshot(x, y, width, height) {
        if (actionInFlight || promptActive || screenshotInFlight)
            return false;
        status = "Capturing Wi-Fi window…";
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function maybeRunPendingRefresh() { scan.maybeRefresh(); }
    function setPower() {
        if (!beginAction())
            return;
        const enabled = !powered;
        status = enabled ? "Turning Wi-Fi on…" : "Turning Wi-Fi off…";
        if (!enabled)
            scan.cancelForPowerOff();
        backend.setPowered(enabled);
    }
    function applyPowerResult(result) {
        const enabled = !!result.enabled;
        const nextRadios = Object.assign({}, radios, { wireless_enabled: enabled });
        activeStatus = Object.assign({}, activeStatus || ({}), {
            enabled: enabled,
            radios: nextRadios,
            active: enabled ? !!(activeStatus && activeStatus.active) : false
        });
        status = result.message || (enabled ? "Wi-Fi turned on" : "Wi-Fi turned off");
    }

    function handleSecretEvent(event) {
        if (event.event === "requested") {
            prompt.openDaemonSecretPrompt(event);
            return;
        }
        if (event.event === "cancelled"
                && (prompt.mode === "daemon-secret" || prompt.credentialMode === "daemon-secret")
                && prompt.secretRequestId === event.request_id) {
            prompt.cancel();
            status = "NetworkManager cancelled the Wi-Fi secret request.";
            return;
        }
        if (event.event === "persistence")
            status = event.status === "stored" ? "Wi-Fi secret saved to the keyring." : "Wi-Fi secret was accepted but could not be saved: " + event.status;
    }

    function applyStatusEvent(event) {
        if (event.event !== "changed")
            return;
        activeStatus = event.status || null;
    }

    function handleDaemonEvent(event) {
        try {
            Api.requireApiEvent(event);
            const handler = daemonEventHandlerByStream[event.stream];
            if (handler)
                handler(event);
            else
                console.warn("shelllist nm event ignored stream=" + event.stream + " event=" + event.event + " reason=no-handler");
        } catch (error) {
            console.error("shelllist nm event rejected stream=" + (event && event.stream ? event.stream : "unknown") + " error=" + error);
            status = "Could not parse nm-daemon event: " + error;
        }
    }

    function failCall(id, message) {
        if (id === "connect-start")
            connection.resetProgress();
        advanced.failCall(id, message);
        if (id === "share")
            services.share.fail(message);
        status = message;
        maybeRunPendingRefresh();
    }

    function requireIdle(ready) {
        if (!ready)
            status = busyMessage;
        return ready;
    }
    function beginAction() { return requireIdle(!actionInFlight); }
    function primarySelected() { return executeSelected(""); }
    function triggerDetailAction(id) { return executeSelected(id); }
    function applyNetworks(networks, resetSelection) { replaceProviderResults(wifiProvider.resultsForNetworks(networks), resetSelection); }

    function openHiddenNetworkPrompt() { if (connection.beginAny()) prompt.openHiddenNetworkPrompt(); }

    onDetailsOpenChanged: {
        if (detailsOpen)
            Qt.callLater(services.share.refresh);
        else if (advanced.open)
            advanced.closeSettings();
    }
    onDetailApChanged: {
        advanced.selectionChanged();
        if (detailsOpen)
            Qt.callLater(services.share.refresh);
    }
    onActiveStatusChanged: connection.updateVisibleProgress()
    onPoweredChanged: {
        if (!powered) {
            detailsOpen = false;
            scan.cancelForPowerOff();
            status = "Wi-Fi is off";
        } else if (uiActive) {
            Qt.callLater(scan.refresh);
        }
    }

    Connections {
        target: wifi.prompt
        function onOpenChanged() { if (!wifi.promptActive) Qt.callLater(wifi.navigation.focusSearch); }
        function onCredentialOpenChanged() { if (!wifi.promptActive) Qt.callLater(wifi.navigation.focusSearch); }
    }
    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: wifi.uiActive
        onCompleted: function (message) { wifi.status = message; }
        onFailed: function (message) { wifi.status = message; }
    }
    WifiControllerServices { id: services; controller: wifi; prompt: wifi.prompt }
    WifiQrService { id: qrController; controller: wifi }
}
