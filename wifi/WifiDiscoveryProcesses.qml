import Quickshell.Io
import QtQuick
import "Wifi.js" as Wifi

Item {
    required property var controller
    readonly property bool listRunning: listProc.running
    readonly property bool scanRunning: scanStreamProc.running

    function refreshCachedNetworks() { listProc.exec(Wifi.nmApiArgs("wifi", "networks", "--cached")); }
    function refreshStatus() { if (!statusProc.running) statusProc.exec(Wifi.nmApiArgs("wifi", "status")); }
    function startScanStream() { if (!scanStreamProc.running) scanStreamProc.exec(Wifi.nmApiArgs("wifi", "scan", "--stream", "--cache", "--timeout", "12")); }

    Process {
        id: listProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (controller.scanSnapshotSeen)
                        return;
                    const networks = Wifi.apiData(JSON.parse(text), "networks") || [];
                    controller.applyNetworks(networks, true);
                    controller.setBackgroundStatus(networks.length + " cached networks; scanning in background…");
                } catch (error) {
                    controller.status = "Could not parse network API networks response: " + error;
                }
            }
        }
        stderr: StdioCollector { id: listErr; waitForEnd: true }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && !controller.scanSnapshotSeen)
                controller.status = "Cached list failed: " + listErr.text;
            controller.maybeRunPendingRefresh();
        }
    }

    Process {
        id: statusProc
        stdout: StdioCollector { id: statusOut; waitForEnd: true }
        stderr: StdioCollector { id: statusErr; waitForEnd: true }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                controller.status = "Status failed: " + statusErr.text;
                return;
            }
            try {
                controller.activeStatus = Wifi.apiData(JSON.parse(statusOut.text), "status");
                controller.applyNetworks(controller.networks, false);
                controller.refreshShareAvailabilityIfOpen();
            } catch (error) {
                controller.status = "Could not parse network API status response: " + error;
            }
        }
    }

    Process {
        id: scanStreamProc
        stdout: SplitParser { splitMarker: "\n"; onRead: function (data) { controller.handleScanEvent(data); } }
        stderr: StdioCollector { id: scanStreamErr; waitForEnd: true }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && scanStreamErr.text.length > 0)
                controller.status = "Background scan failed: " + scanStreamErr.text;
            controller.maybeRunPendingRefresh();
        }
    }
}
