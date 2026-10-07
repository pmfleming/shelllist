import QtQuick
import "WifiFlow.js" as Flow
import "process"
import "NmApi.js" as NmApi
import "."
import Shelllist.Io as Io
import Shelllist.Ui

ProviderChooserController {
    id: wifi

    viewMemory: ChooserMemory {
        controller: wifi
        key: wifi.selectedResult ? (wifi.selectedResult.key || "") : ""
        tab: wifi.detailsTab
        tabs: wifi.profileFor(wifi.detailAp) ? ["network", "security", "hardware"] : ["network"]
        onRestoreRequested: function (open, tab) {
            wifi.detailsOpen = open && wifi.hasSelection && wifi.powered;
            if (wifi.detailsOpen)
                wifi.selectDetailsTab(tab);
        }
    }
    required property WifiPromptController prompt
    provider: WifiProvider {
        id: wifiProvider
        controller: wifi
    }
    sharedScreenshotEnabled: true
    sharedScreenshotBlocked: promptActive
    sharedScreenshotStartMessage: "Capturing Wi-Fi window…"
    onSharedScreenshotStatusChanged: function (message) {
        status = message;
    }

    property var activeStatus: null
    property bool statusMonitorActive: false
    property var networkSnapshot: null
    property var visibleNetworks: []
    property bool networksLoaded: false
    property string networksError: ""
    property string status
    property var bandStatus: null
    // Result of the most recent wifi.qr.parse; never contains the passphrase.
    property var scannedQr: null
    property string bandRequestId: ""
    readonly property var radios: activeStatus && activeStatus.radios ? activeStatus.radios : ({
            wireless_enabled: !activeStatus || activeStatus.enabled !== false,
            wireless_hardware_enabled: true,
            wireless_available: true
        })
    readonly property bool powered: radios.wireless_enabled !== false && radios.wireless_hardware_enabled !== false
    property double statusHoldUntil: 0
    readonly property WifiBackend backend: services.backend
    readonly property bool screenshotInFlight: sharedScreenshotInFlight
    readonly property bool promptActive: prompt.open || prompt.credentialOpen || qr.open
    actionInFlight: backend.running || bandRequestId.length > 0
    readonly property string detailsTab: advanced.open ? advanced.section : "network"
    readonly property bool scanInFlight: scan.running
    readonly property var detailResult: selectedResult
    readonly property var detailAp: detailResult ? detailResult.payload : ({})
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property ShareAvailabilityController shareController: services.share
    navigationBlocked: promptActive || !powered
    readonly property WifiAdvancedController advanced: services.advanced
    readonly property CaptivePortalController portal: services.portal
    readonly property WifiConnectionController connection: services.connection
    readonly property WifiNetworkActions actions: services.actions
    readonly property WifiScanController scan: services.scan
    readonly property NetworkHealthController health: services.health
    readonly property HotspotController hotspot: services.hotspot
    readonly property VpnController vpn: services.vpn
    readonly property NetworkInventoryController inventory: services.inventory
    readonly property NetworkStatisticsController statistics: services.statistics
    readonly property WifiQrService qr: qrController
    readonly property var daemonEventHandlerByStream: {
        const handlers = ({});
        handlers[NmApi.streams.wifi_status] = wifi.applyStatusEvent;
        handlers[NmApi.streams.network_connectivity] = connection.applyConnectivityEvent;
        handlers[NmApi.streams.wifi_networks] = wifi.applyNetworkEvent;
        handlers[NmApi.streams.wifi_scan] = scan.handleStream;
        handlers[NmApi.streams.wifi_connect] = connection.handleEvent;
        handlers[NmApi.streams.wifi_band] = wifi.handleBandEvent;
        handlers[NmApi.streams.wifi_secret] = wifi.handleSecretEvent;
        handlers[NmApi.streams.network_health] = health.handleEvent;
        handlers[NmApi.streams.network_inventory] = inventory.handleEvent;
        handlers[NmApi.streams.network_statistics] = statistics.handleEvent;
        handlers[NmApi.streams.hotspot] = hotspot.handleEvent;
        handlers[NmApi.streams.vpn] = vpn.handleEvent;
        return handlers;
    }

    signal advancedSectionLeaving(string section)

    function activeAccessPoint() {
        return activeStatus ? (activeStatus.access_point || activeStatus.network || null) : null;
    }
    function activeNetworkKey() {
        return activeStatus && activeStatus.network ? (activeStatus.network.key || "") : "";
    }
    function isActive(ap) {
        return !!(ap && ap.active);
    }
    function profileFor(ap) {
        return Flow.profileForAccessPoint(ap);
    }
    function selectDetailsTab(tab) {
        if (tab === "network")
            advanced.closeSettings();
        else
            advanced.selectSection(tab);
    }

    function cycleDetailsTab(backwards: bool) {
        if (!detailsOpen)
            return;
        const tabs = profileFor(detailAp) ? ["network", "security", "hardware"] : ["network"];
        selectDetailsTab(tabAfter(tabs, detailsTab, backwards));
    }

    function invalidateShareAvailabilityCache() {
        services.share.invalidate();
    }
    function shareSelected() {
        services.share.showSelected();
    }
    // Scanning from the network list joins the network it read; scanning from
    // the share dialog only reports what it read.
    function launchQrScanner() {
        return !promptActive && qr.launchScanner(true);
    }
    function applyShareResponse(response, errorText) {
        services.share.applyResponse(response, errorText);
    }
    function statusIsHeld() {
        return Date.now() < statusHoldUntil;
    }
    function setBackgroundStatus(message) {
        if (!statusIsHeld() && !actionInFlight)
            status = message;
    }
    function setHeldStatus(message, milliseconds) {
        status = message;
        statusHoldUntil = Date.now() + milliseconds;
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scan.activate();
        connection.activate();
        // Hotspot and VPN state is cheap to read and needed the moment their
        // controls are shown; the inventory stream stays unsubscribed until a
        // view asks for it.
        hotspot.refresh();
        vpn.refresh();
    }

    function deactivateUi() {
        if (promptActive)
            cancelPrompt("popover-hidden");
        deactivateUiState();
        scan.deactivate();
        connection.deactivate();
        hotspot.forgetCredentials();
        inventory.close();
        statistics.stop();
    }

    // Entry points for hotspot, VPN, and cross-type connection views.
    function startHotspot(options) {
        return hotspot.start(options);
    }
    function stopHotspot() {
        return hotspot.stop();
    }
    function connectVpn(profile) {
        return vpn.connect(profile);
    }
    function disconnectVpn(profile) {
        return vpn.disconnect(profile);
    }
    function deactivateConnection(activeConnection) {
        return inventory.deactivate(activeConnection);
    }

    function dismissNavigation(): bool {
        if (promptActive)
            return false;
        if (advanced.open) {
            advanced.closeSettings();
            return true;
        }
        return dismissDetailsOrWindow();
    }

    function promptMode(): string {
        return prompt.credentialOpen ? prompt.credentialMode : prompt.mode;
    }
    function cancelPendingSecret(mode: string, requestId: string): bool {
        if (mode !== "daemon-secret" || !requestId)
            return true;
        return connection.cancelSecret(requestId);
    }
    function cancelPrompt(reason) {
        if (qr.open) {
            qr.close();
            return true;
        }
        if (!promptActive)
            return true;
        const mode = promptMode();
        const cancelled = cancelPendingSecret(mode, prompt.secretRequestId);
        prompt.cancel();
        console.info("shelllist wifi prompt closed mode=" + mode + " reason=" + (reason || "user") + " daemon_cancelled=" + cancelled);
        if (!cancelled)
            status = "Could not cancel the pending Wi-Fi secret request.";
        return cancelled;
    }

    function handleTransportFailure(message, lostRequestIds) {
        networksError = message;
        const lost = lostRequestIds || [];
        scan.handleTransportFailure();
        connection.handleTransportFailure();
        portal.transportLost();
        statistics.handleTransportFailure();
        bandRequestId = "";
        lost.forEach(function (id) {
            advanced.failCall(id, "nm-daemon transport failed before " + id + " completed: " + message);
        });
        if (lost.indexOf("share") >= 0)
            services.share.fail(message);
        if (promptActive && promptMode() === "daemon-secret") {
            console.warn("shelllist wifi daemon secret prompt discarded reason=transport-failure request_id=" + prompt.secretRequestId);
            prompt.cancel();
        }
        status = message + (lost.length > 0 ? " Lost requests: " + lost.join(", ") + "." : "");
    }

    function handleTransportReady() {
        if (uiActive)
            scan.maybeRefresh();
    }

    function refresh() {
        scan.refresh();
    }
    function copyText(text, message) {
        if (!clipboardPublisher.publishText(text, message)) {
            status = "Clipboard publication is already in progress";
            return false;
        }
        status = "Copying to the clipboard…";
        return true;
    }
    function maybeRunPendingRefresh() {
        scan.maybeRefresh();
    }
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
        activeStatus = Flow.powerStatus(activeStatus, radios, enabled);
        status = result.message || (enabled ? "Wi-Fi turned on" : "Wi-Fi turned off");
    }

    function loadBandStatus(path) {
        if (!path || backend.isPending("band-status"))
            return false;
        return backend.loadBandStatus(path);
    }
    function applyBandStatus(value) {
        bandStatus = value && value.path ? value : null;
    }
    function setBand(path, band) {
        if (!path || !band || bandRequestId.length > 0 || backend.running)
            return false;
        status = "Changing Wi-Fi band…";
        return backend.setBand(path, band);
    }
    function applyBandStart(result) {
        bandRequestId = result.request_id || "";
        status = result.message || "Wi-Fi band change started…";
    }
    function handleBandEvent(event: var): void {
        const transition = Flow.bandTransition(event, bandRequestId);
        if (transition.stage === "ignored")
            return;
        status = transition.message || status;
        if (transition.stage === "running")
            return;
        bandRequestId = "";
        if (transition.stage === "completed") {
            applyBandStatus(transition.band);
            refresh();
        }
    }

    function handleSecretEvent(event: var): void {
        const transition = Flow.secretTransition(event, promptMode(), prompt.secretRequestId);
        if (transition.stage === "requested")
            prompt.openDaemonSecretPrompt(event);
        else if (transition.stage === "cancelled")
            prompt.cancel();
        if (transition.message)
            status = transition.message;
    }

    function applyRecoveredStatus(value: var): void {
        activeStatus = value || null;
    }

    function applyStatusEvent(event: var): void {
        if (event.event !== "changed")
            return;
        applyRecoveredStatus(event.status || null);
    }

    function applyNetworkEvent(event: var): void {
        if (event.event !== "changed")
            return;
        const networks = event.initial ? (event.added || []) : Flow.mergeNetworkChanges(visibleNetworks, event);
        applyNetworks(networks, false, event.snapshot || null);
    }

    function dispatchDaemonEvent(event: var): void {
        if (!backend.routeEvent(event, daemonEventHandlerByStream))
            console.warn("shelllist nm event ignored stream=" + event.stream + " event=" + event.event + " reason=no-handler");
    }
    function rejectDaemonEvent(event: var, error: var): void {
        const stream = event && event.stream ? event.stream : "unknown";
        console.error("shelllist nm event rejected stream=" + stream + " error=" + error);
        status = "Could not parse nm-daemon event: " + error;
    }
    function handleDaemonEventGap(stream: string): void {
        status = "Network events were missed; recovering current state…";
        if (stream === NmApi.streams.network_inventory) {
            inventory.refresh();
            return;
        }
        if (stream === NmApi.streams.network_statistics) {
            statistics.handleEventGap();
            return;
        }
        if (stream === NmApi.streams.hotspot) {
            hotspot.refresh();
            return;
        }
        if (stream === NmApi.streams.vpn) {
            vpn.refresh();
            return;
        }
        if (stream === NmApi.streams.wifi_connect)
            connection.checkStatus(true);
        backend.recoverStatus();
        backend.refreshNetworks(true);
    }
    function handleDaemonEvent(event) {
        try {
            dispatchDaemonEvent(event);
        } catch (error) {
            rejectDaemonEvent(event, error);
        }
    }

    function failCall(id, message, details) {
        if (id === "networks" || id === "scan-start")
            networksError = message;
        if (id === "connect-start" || id === "qr-connect")
            connection.resetProgress();
        advanced.failCall(id, message, details);
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
    function beginAction() {
        return requireIdle(!actionInFlight);
    }
    function primarySelected() {
        return executeSelected("");
    }
    function triggerDetailAction(id) {
        return executeSelected(id);
    }
    function applyNetworks(networks, resetSelection, snapshot) {
        networksLoaded = true;
        networksError = "";
        visibleNetworks = networks || [];
        if (snapshot)
            networkSnapshot = snapshot;
        replaceProviderResults(wifiProvider.resultsFor(visibleNetworks), resetSelection);
    }

    function openHiddenNetworkPrompt() {
        if (connection.beginAny())
            prompt.openHiddenNetworkPrompt();
    }

    // A scanned Wi-Fi QR payload. The payload carries a passphrase, so it is
    // handed straight to the daemon and never held or logged here.
    function joinScannedQr(payload) {
        if (!payload || payload.length === 0) {
            status = "Nothing was scanned.";
            return false;
        }
        if (!connection.canBeginAny() || bandRequestId.length > 0) {
            // Do not retain a scanned passphrase in QML or silently join later.
            // Parsing is read-only; the daemon returns only non-secret metadata.
            status = "Network change in progress; reading QR only. Scan again to join when it finishes.";
            return backend.parseQr(payload);
        }
        return backend.connectQr(payload, "");
    }
    function inspectScannedQr(payload) {
        if (!payload || payload.length === 0) {
            status = "Nothing was scanned.";
            return false;
        }
        return backend.parseQr(payload);
    }
    function applyScannedQr(parsed) {
        scannedQr = parsed || null;
        status = parsed && parsed.ssid ? ("Scanned " + parsed.ssid + (parsed.hidden ? " (hidden)" : "") + ". Scan again to join when network changes finish.") : "The scanned code is not a Wi-Fi network.";
    }

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

    Io.ClipboardPublisher {
        id: clipboardPublisher
        onFinished: function (succeeded, message) {
            wifi.status = message;
        }
    }
    WifiControllerServices {
        id: services
        controller: wifi
        prompt: wifi.prompt
    }
    WifiQrService {
        id: qrController
        controller: wifi
        onScanned: function (payload, join) {
            if (join)
                wifi.joinScannedQr(payload);
            else
                wifi.inspectScannedQr(payload);
        }
        onCopyRequested: function (text, message) {
            wifi.copyText(text, message);
        }
    }
}
