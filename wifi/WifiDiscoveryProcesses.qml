import QtQuick
import "Wifi.js" as Wifi
import "."

Item {
    id: discovery

    required property var controller
    readonly property bool listRunning: listProc.running
    readonly property bool scanRunning: scanStartProc.running || controller.activeScanRequestId.length > 0

    function refreshCachedNetworks() {
        listProc.exec(["shelllist-nm-daemon-call", "wifi.networks", JSON.stringify({ cached: true, refresh_cache: false, refresh_timeout: 10 })]);
    }

    function refreshStatus() {
        if (!statusProc.running)
            statusProc.exec(["shelllist-nm-daemon-call", "wifi.status", "{}"]);
        refreshConnectivity();
    }

    function refreshConnectivity() {
        if (!connectivityProc.running)
            connectivityProc.exec(["shelllist-nm-daemon-call", "network.connectivity", "{}"]);
    }

    function startScanStream() {
        if (!controller.connectRunning && !scanRunning)
            scanStartProc.exec(["shelllist-nm-daemon-call", "wifi.scan", JSON.stringify({ timeout: 12, strict: false, cache: true, ifname: null, ssids: [] })]);
    }

    function finishCachedNetworks(exitCode, outputText, errorText) {
        try {
            if (exitCode === 0 && !controller.scanSnapshotSeen) {
                const networks = Wifi.apiData(JSON.parse(outputText), "networks") || [];
                controller.applyNetworks(networks, true);
                controller.setBackgroundStatus(networks.length + " cached networks; scanning in background…");
            } else if (exitCode !== 0 && !controller.scanSnapshotSeen) {
                controller.status = "Cached list failed: " + errorText;
            }
        } catch (error) {
            controller.status = "Could not parse network API networks response: " + error;
        }
        controller.maybeRunPendingRefresh();
    }

    function finishStatus(exitCode, outputText, errorText) {
        if (exitCode !== 0) {
            controller.status = "Status failed: " + errorText;
            return;
        }
        try {
            controller.activeStatus = Wifi.apiData(JSON.parse(outputText), "status");
            controller.applyNetworks(controller.networks, false);
            controller.refreshShareAvailabilityIfOpen();
        } catch (error) {
            controller.status = "Could not parse network API status response: " + error;
        }
    }

    function finishConnectivity(exitCode, outputText, errorText) {
        if (exitCode !== 0)
            return;
        try { controller.networkConnectivity = Wifi.apiData(JSON.parse(outputText), "connectivity"); }
        catch (error) { console.log("Could not parse network connectivity response: " + error + " " + errorText); }
    }

    function finishScanStart(exitCode, outputText, errorText) {
        if (exitCode !== 0) {
            controller.status = "Background scan failed to start: " + errorText;
            controller.maybeRunPendingRefresh();
            return;
        }
        try {
            const result = Wifi.apiResult(JSON.parse(outputText), "result") || ({});
            if (result.status === "error") {
                controller.status = result.message || "Background scan failed to start";
                controller.maybeRunPendingRefresh();
                return;
            }
            controller.activeScanRequestId = result.request_id || "";
            controller.setBackgroundStatus(result.message || "Wi-Fi scan started…");
        } catch (error) {
            controller.status = "Could not parse scan start response: " + error;
            controller.maybeRunPendingRefresh();
        }
    }

    CommandProcess {
        id: listProc
        onFinished: function (exitCode, outputText, errorText) { discovery.finishCachedNetworks(exitCode, outputText, errorText); }
    }

    CommandProcess {
        id: statusProc
        onFinished: function (exitCode, outputText, errorText) { discovery.finishStatus(exitCode, outputText, errorText); }
    }

    CommandProcess {
        id: connectivityProc
        onFinished: function (exitCode, outputText, errorText) { discovery.finishConnectivity(exitCode, outputText, errorText); }
    }

    CommandProcess {
        id: scanStartProc
        onFinished: function (exitCode, outputText, errorText) { discovery.finishScanStart(exitCode, outputText, errorText); }
    }
}
