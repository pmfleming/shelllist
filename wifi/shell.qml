import Quickshell
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: root

    property var networks: []
    property var optionItems: []
    property var activeStatus: null
    property string filterText: ""
    property int selectedIndex: 0
    property bool statusRefreshInFlight: false
    property string status: "Loading Wi-Fi networks…"
    property string lastConnectedSsid: ""
    property bool scanSnapshotSeen: false
    property bool promptOpen: false
    property string promptMode: ""
    property string promptTitle: ""
    property string promptDetail: ""
    property string promptText: ""
    property bool promptPassword: false
    property var promptNetwork: null
    property string pendingHiddenSsid: ""

    readonly property string helpText: "Enter connect   •   F6 hidden network   •   F5 refresh   •   Esc close"
    readonly property var filteredNetworks: networks.filter(function (ap) {
        return !root.filterText || (ap.ssid || "").toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1;
    })
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0

    function clampIndex(index, length) {
        return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1));
    }

    function selectedNetwork() {
        if (filteredNetworks.length === 0)
            return null;
        selectedIndex = clampIndex(selectedIndex, filteredNetworks.length);
        return filteredNetworks[selectedIndex];
    }

    function networkName(ap) {
        return ap && ap.ssid ? ap.ssid : "<hidden>";
    }

    function securityLabel(security) {
        return security === "--" ? "Open" : (security || "Unknown");
    }

    function hasNetworkIdentity(ap) {
        return !!(ap && ((ap.ssid_bytes && ap.ssid_bytes.length > 0) || (ap.ssid && ap.ssid.length > 0)));
    }

    function canConnect(ap) {
        if (!ap)
            return false;
        if (ap.capabilities)
            return ap.capabilities.can_connect;
        return hasNetworkIdentity(ap);
    }

    function needsPassword(ap) {
        return !!(ap && hasNetworkIdentity(ap) && ap.capabilities && ap.capabilities.needs_password);
    }

    function canStartConnection(ap) {
        return canConnect(ap) || needsPassword(ap);
    }

    function sameAccessPoint(left, right) {
        if (!left || !right)
            return false;
        return (left.path && right.path === left.path) || (left.bssid && right.bssid === left.bssid) || ((left.ssid || "") === (right.ssid || "") && (left.security || "") === (right.security || ""));
    }

    function activeAccessPoint() {
        if (!activeStatus)
            return null;
        return activeStatus.access_point || (activeStatus.network || null);
    }

    function isActive(ap) {
        const active = activeAccessPoint();
        return !!(ap && (ap.active || sameAccessPoint(ap, active)));
    }

    function profileFor(ap) {
        if (!ap)
            return null;
        if (ap.primary_profile)
            return ap.primary_profile;
        if (ap.profiles && ap.profiles.length > 0)
            return ap.profiles[0];
        if (isActive(ap) && activeStatus && activeStatus.profile)
            return activeStatus.profile;
        return null;
    }

    function frequencyLabel(ap) {
        const frequency = ap && ap.frequency ? ap.frequency : 0;
        if (frequency <= 0)
            return "Unknown";
        const band = frequency >= 5925 ? "6 GHz" : frequency >= 4900 ? "5 GHz" : "2.4 GHz";
        return band + " (" + frequency + " MHz)";
    }

    function wifiType(ap) {
        const frequency = ap && ap.frequency ? ap.frequency : 0;
        if (frequency >= 5925)
            return "Wi-Fi 6E/7";
        if (frequency >= 4900)
            return "Wi-Fi 5/6";
        if (frequency > 0)
            return "Wi-Fi 4/6";
        return "Unknown";
    }

    function subnetLabel(ip4) {
        if (!ip4)
            return "—";
        if (ip4.prefix !== null && ip4.prefix !== undefined)
            return "/" + ip4.prefix;
        return "—";
    }

    function dnsLabel(ip4) {
        if (!ip4 || !ip4.dns || ip4.dns.length === 0)
            return "—";
        return ip4.dns.join(", ");
    }

    function bitrateLabel() {
        const wireless = activeStatus && activeStatus.wireless ? activeStatus.wireless : null;
        if (!wireless || !wireless.bitrate_mbps)
            return "—";
        return wireless.bitrate_mbps + " Mbps";
    }

    function macLabel() {
        const wireless = activeStatus && activeStatus.wireless ? activeStatus.wireless : null;
        return wireless && wireless.mac_address ? wireless.mac_address : "—";
    }

    function applyNetworks(newNetworks, resetSelection) {
        const previous = selectedNetwork();
        networks = newNetworks;

        if (resetSelection || !previous) {
            const activeIndex = filteredNetworks.findIndex(function (ap) {
                return root.isActive(ap);
            });
            selectedIndex = activeIndex >= 0 ? activeIndex : 0;
        } else {
            const nextIndex = filteredNetworks.findIndex(function (ap) {
                return sameAccessPoint(previous, ap);
            });
            selectedIndex = nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, filteredNetworks.length);
        }
    }

    function refresh() {
        status = "Loading cached Wi-Fi networks…";
        scanSnapshotSeen = false;
        listProc.exec(["nm-wifi", "networks", "--cached", "--json"]);
        refreshStatus();
        startScanStream();
    }

    function refreshStatus() {
        if (!statusProc.running)
            statusProc.exec(["nm-wifi", "status", "--json"]);
    }

    function startScanStream() {
        if (!scanStreamProc.running)
            scanStreamProc.exec(["nm-wifi", "scan", "--stream", "--cache", "--timeout", "12"]);
    }

    function handleScanEvent(line) {
        const trimmed = line.trim();
        if (!trimmed)
            return;

        try {
            const event = JSON.parse(trimmed);
            const handlers = {
                snapshot: function (e) {
                    scanSnapshotSeen = true;
                    applyNetworks(e.networks || [], false);
                    status = e.networks_found + (e.scanning ? " networks found; scanning…" : " networks available");
                },
                status: function (e) {
                    status = e.message || status;
                },
                warning: function (e) {
                    status = e.message || status;
                },
                complete: function (e) {
                    status = e.networks_found + (e.timed_out ? " networks available; scan timed out" : " networks available");
                    refreshStatus();
                }
            };
            if (handlers[event.event])
                handlers[event.event](event);
        } catch (error) {
            status = "Could not parse scan event: " + error;
        }
    }

    function connectSelected() {
        const ap = selectedNetwork();
        if (!ap)
            return;
        if (needsPassword(ap)) {
            openPasswordPrompt(ap);
            return;
        }
        if (!canConnect(ap)) {
            status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
            return;
        }

        runConnect(["nm-wifi", "connect-target", JSON.stringify(ap), "--json"], networkName(ap));
    }

    function runConnect(args, displayName) {
        status = "Connecting to " + displayName + "…";
        lastConnectedSsid = displayName;
        connectProc.exec(args);
    }

    function disconnectSelected() {
        status = "Disconnecting Wi-Fi…";
        disconnectProc.exec(["nm-wifi", "disconnect", "--json"]);
    }

    function forgetSelected() {
        const profile = profileFor(selectedNetwork());
        if (!profile)
            return;
        status = "Forgetting saved profile " + profile.id + "…";
        profileProc.exec(["nm-wifi", "profile", "delete", profile.path]);
    }

    function toggleAutoconnectSelected() {
        const profile = profileFor(selectedNetwork());
        if (!profile)
            return;
        const enabled = !profile.autoconnect;
        status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…";
        profileProc.exec(["nm-wifi", "profile", "autoconnect", profile.path, enabled ? "true" : "false"]);
    }

    function openPortal() {
        status = "Opening captive portal pages…";
        portalProc.exec(["shelllist-captive-portal"]);
    }

    function openPasswordPrompt(ap) {
        promptNetwork = ap;
        promptMode = "network-password";
        promptTitle = "Password for " + networkName(ap);
        promptDetail = "Enter the Wi-Fi password, then press Enter.";
        promptText = "";
        promptPassword = true;
        promptOpen = true;
    }

    function openHiddenNetworkPrompt() {
        promptNetwork = null;
        pendingHiddenSsid = "";
        promptMode = "hidden-ssid";
        promptTitle = "Connect hidden network";
        promptDetail = "Enter the hidden SSID, then press Enter.";
        promptText = "";
        promptPassword = false;
        promptOpen = true;
    }

    function openHiddenPasswordPrompt(ssid) {
        pendingHiddenSsid = ssid;
        promptMode = "hidden-password";
        promptTitle = "Password for hidden network";
        promptDetail = "Enter the password for " + ssid + ", or leave blank for an open network.";
        promptText = "";
        promptPassword = true;
        promptOpen = true;
    }

    function cancelPrompt() {
        promptOpen = false;
        promptText = "";
        promptMode = "";
        promptNetwork = null;
        pendingHiddenSsid = "";
    }

    function submitPrompt() {
        const value = promptText;
        if (promptMode === "network-password") {
            if (value.length === 0) {
                status = "Enter a password for this network.";
                return;
            }
            const ap = promptNetwork;
            cancelPrompt();
            if (!ap)
                return;
            runConnect(["nm-wifi", "connect-target", JSON.stringify(ap), "--password", value, "--json"], networkName(ap));
            return;
        }

        if (promptMode === "hidden-ssid") {
            const ssid = value;
            if (ssid.length === 0) {
                status = "Enter an SSID for the hidden network.";
                return;
            }
            openHiddenPasswordPrompt(ssid);
            return;
        }

        if (promptMode === "hidden-password") {
            const ssid = pendingHiddenSsid;
            const args = ["nm-wifi", "connect", ssid, "--hidden", "--json"];
            if (value.length > 0)
                args.push("--password", value);
            cancelPrompt();
            runConnect(args, ssid);
        }
    }

    function acceptKey(event, action) {
        action();
        event.accepted = true;
    }

    function isEnterKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter;
    }

    function moveSelection(delta) {
        selectedIndex = clampIndex(selectedIndex + delta, filteredNetworks.length);
    }

    function handleBinding(event, bindings) {
        for (let i = 0; i < bindings.length; i++) {
            if (event.key === bindings[i][0])
                return acceptKey(event, bindings[i][1]);
        }
    }

    function handleSearchKey(event) {
        if (promptOpen)
            return;
        if (isEnterKey(event.key))
            return acceptKey(event, connectSelected);
        return handleBinding(event, [[Qt.Key_Escape, Qt.quit], [Qt.Key_Down, function () {
                    moveSelection(1);
                }], [Qt.Key_Up, function () {
                    moveSelection(-1);
                }], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }

    onPromptOpenChanged: {
        if (promptOpen)
            Qt.callLater(function () {
                promptInput.forceActiveFocus();
                promptInput.selectAll();
            });
        else
            Qt.callLater(function () {
                search.forceActiveFocus();
            });
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (root.scanSnapshotSeen)
                        return;
                    const networks = JSON.parse(text);
                    root.applyNetworks(networks, true);
                    root.status = networks.length + " cached networks; scanning in background…";
                } catch (error) {
                    root.status = "Could not parse nm-wifi networks output: " + error;
                }
            }
        }
        stderr: StdioCollector {
            id: listErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && !root.scanSnapshotSeen)
                root.status = "Cached list failed: " + listErr.text;
        }
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            id: statusOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: statusErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Status failed: " + statusErr.text;
                return;
            }
            try {
                root.activeStatus = JSON.parse(statusOut.text);
                root.applyNetworks(root.networks, false);
            } catch (error) {
                root.status = "Could not parse nm-wifi status output: " + error;
            }
        }
    }

    Process {
        id: scanStreamProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) {
                root.handleScanEvent(data);
            }
        }
        stderr: StdioCollector {
            id: scanStreamErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && scanStreamErr.text.length > 0)
                root.status = "Background scan failed: " + scanStreamErr.text;
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {
            id: connectOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: connectErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Connect failed: " + connectErr.text;
                return;
            }

            try {
                const result = JSON.parse(connectOut.text);
                const connectivity = result.connectivity || {};
                if (result.suggest_open_portal) {
                    root.status = result.message + "; opening captive portal…";
                    root.openPortal();
                } else if (connectivity.state === "full") {
                    root.status = "Connected to " + result.ssid + " with full connectivity";
                } else if (connectivity.state) {
                    root.status = "Connected to " + result.ssid + "; connectivity: " + connectivity.state;
                } else {
                    root.status = result.message;
                }
            } catch (error) {
                root.status = "Connected to " + root.lastConnectedSsid + "; could not parse connect result: " + error;
            }
            root.refresh();
        }
    }

    Process {
        id: disconnectProc
        stdout: StdioCollector {
            id: disconnectOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: disconnectErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Disconnect failed: " + disconnectErr.text;
                return;
            }
            try {
                const result = JSON.parse(disconnectOut.text);
                root.status = result.message || "Disconnected Wi-Fi";
            } catch (error) {
                root.status = "Disconnected Wi-Fi";
            }
            root.refresh();
        }
    }

    Process {
        id: profileProc
        stderr: StdioCollector {
            id: profileErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Profile action failed: " + profileErr.text;
                return;
            }
            root.status = "Saved profile updated";
            root.refresh();
        }
    }

    Process {
        id: portalProc
        stderr: StdioCollector {
            id: portalErr
            waitForEnd: false
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && portalErr.text.length > 0)
                root.status = "Could not open captive portal browser: " + portalErr.text;
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1040
        implicitHeight: 720
        title: "Shelllist Wi-Fi"
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#0b1220"
            border.color: "#243244"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Row {
                    width: parent.width
                    height: 46
                    spacing: 12

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#15335f"
                        Text {
                            anchors.centerIn: parent
                            text: "󰤨"
                            color: "#7dd3fc"
                            font.pixelSize: 18
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Shelllist Wi-Fi"
                        color: "#dbeafe"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    TextInput {
                        id: search
                        width: 270
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        focus: true
                        leftPadding: 38
                        rightPadding: 12
                        color: "#dbeafe"
                        selectionColor: "#2563eb"
                        selectedTextColor: "white"
                        font.pixelSize: 15
                        text: root.filterText
                        onTextChanged: {
                            root.filterText = text;
                            root.selectedIndex = 0;
                        }
                        Keys.onPressed: function (event) {
                            root.handleSearchKey(event);
                        }

                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⌕"
                            color: "#64748b"
                            font.pixelSize: 22
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "#111827"
                            border.color: "#233247"
                            z: -1
                        }
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        border.color: "#233247"
                        Text {
                            anchors.centerIn: parent
                            text: "↻"
                            color: "#94a3b8"
                            font.pixelSize: 20
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.refresh()
                        }
                    }

                    Item {
                        width: parent.width - 34 - 140 - 270 - 34 - 72
                        height: 1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "☰   –   ◻   ×"
                        color: "#94a3b8"
                        font.pixelSize: 16
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 58
                    spacing: 12

                    Rectangle {
                        width: 425
                        height: parent.height
                        radius: 12
                        color: "#0f172a"
                        border.color: "#1f2a3a"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Text {
                                width: parent.width
                                text: root.status + "   •   " + root.helpText
                                color: "#94a3b8"
                                font.pixelSize: 13
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }

                            ListView {
                                id: list
                                width: parent.width
                                height: parent.height - 42
                                clip: true
                                model: root.filteredNetworks
                                spacing: 3

                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData

                                    width: ListView.view.width
                                    height: 43
                                    radius: 8
                                    color: index === root.selectedIndex ? "#15335f" : "transparent"
                                    border.color: index === root.selectedIndex ? "#3b82f6" : "transparent"
                                    border.width: index === root.selectedIndex ? 1 : 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Text {
                                            width: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (modelData.strength || 0) + "%"
                                            color: "#bfdbfe"
                                            font.pixelSize: 14
                                        }

                                        Text {
                                            width: 22
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "▂▄▆"
                                            color: root.isActive(modelData) ? "#38bdf8" : "#94a3b8"
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            width: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.isActive(modelData) ? "●" : (modelData.security === "--" ? "Open" : "🔒")
                                            color: root.isActive(modelData) ? "#22c55e" : (modelData.security === "--" ? "#fbbf24" : "#94a3b8")
                                            font.pixelSize: modelData.security === "--" && !root.isActive(modelData) ? 8 : 13
                                        }

                                        Text {
                                            width: parent.width - 122
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.networkName(modelData)
                                            color: "#d1d5db"
                                            font.pixelSize: 15
                                            font.bold: root.isActive(modelData)
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "›"
                                            color: "#94a3b8"
                                            font.pixelSize: 25
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.selectedIndex = index
                                        onDoubleClicked: root.connectSelected()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 437
                        height: parent.height
                        radius: 12
                        color: "#0f172a"
                        border.color: "#1f2a3a"

                        Item {
                            anchors.fill: parent
                            anchors.margins: 18

                            Column {
                                visible: root.hasSelection
                                anchors.fill: parent
                                spacing: 14

                                Row {
                                    width: parent.width
                                    height: 72
                                    spacing: 16

                                    Text {
                                        width: 54
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰤨"
                                        color: "#dbeafe"
                                        font.pixelSize: 42
                                    }

                                    Column {
                                        width: parent.width - 70
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            text: root.networkName(root.detailAp)
                                            color: "#f8fafc"
                                            font.pixelSize: 24
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.isActive(root.detailAp) ? "Connected · " + (root.detailAp.strength || 0) + "% signal" : root.securityLabel(root.detailAp.security) + " · " + (root.detailAp.strength || 0) + "% signal"
                                            color: root.isActive(root.detailAp) ? "#4ade80" : "#94a3b8"
                                            font.pixelSize: 14
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    height: 46
                                    spacing: 8

                                    Rectangle {
                                        width: 112
                                        height: 42
                                        radius: 8
                                        color: root.isActive(root.detailAp) ? "#1e3a5f" : "#1d4ed8"
                                        border.color: "#3b82f6"
                                        opacity: root.canStartConnection(root.detailAp) || root.isActive(root.detailAp) ? 1.0 : 0.45
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.isActive(root.detailAp) ? "Disconnect" : "Connect"
                                            color: "#dbeafe"
                                            font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.isActive(root.detailAp) ? root.disconnectSelected() : root.connectSelected()
                                        }
                                    }

                                    Rectangle {
                                        width: 90
                                        height: 42
                                        radius: 8
                                        color: "#111827"
                                        border.color: "#233247"
                                        opacity: root.profileFor(root.detailAp) ? 1.0 : 0.45
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Forget"
                                            color: "#cbd5e1"
                                            font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.forgetSelected()
                                        }
                                    }

                                    Rectangle {
                                        width: 90
                                        height: 42
                                        radius: 8
                                        color: "#111827"
                                        border.color: "#233247"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Sign in"
                                            color: "#cbd5e1"
                                            font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.openPortal()
                                        }
                                    }

                                    Rectangle {
                                        width: 90
                                        height: 42
                                        radius: 8
                                        color: "#111827"
                                        border.color: "#233247"
                                        opacity: 0.45
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Share"
                                            color: "#94a3b8"
                                            font.pixelSize: 13
                                        }
                                    }

                                    Item {
                                        width: parent.width - 112 - 90 - 90 - 90 - 164
                                        height: 1
                                    }

                                    Rectangle {
                                        width: 150
                                        height: 42
                                        radius: 8
                                        color: "#111827"
                                        border.color: "#233247"
                                        opacity: root.profileFor(root.detailAp) ? 1.0 : 0.45
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 10
                                            Text {
                                                text: "Auto-connect"
                                                color: "#cbd5e1"
                                                font.pixelSize: 13
                                            }
                                            Rectangle {
                                                width: 34
                                                height: 20
                                                radius: 10
                                                color: root.profileFor(root.detailAp) && root.profileFor(root.detailAp).autoconnect ? "#3b82f6" : "#334155"
                                                Rectangle {
                                                    width: 14
                                                    height: 14
                                                    radius: 7
                                                    y: 3
                                                    x: root.profileFor(root.detailAp) && root.profileFor(root.detailAp).autoconnect ? 17 : 3
                                                    color: "#dbeafe"
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.toggleAutoconnectSelected()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 250
                                    radius: 10
                                    color: "#0b1320"
                                    border.color: "#1f2a3a"

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Text {
                                            text: "Connection"
                                            color: "#e5e7eb"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        Grid {
                                            width: parent.width
                                            columns: 2
                                            columnSpacing: 46
                                            rowSpacing: 14

                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Signal strength"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: (root.detailAp.strength || 0) + "%"
                                                    color: "#60a5fa"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "IP address"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) && root.activeStatus && root.activeStatus.ip4 && root.activeStatus.ip4.address ? root.activeStatus.ip4.address : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Frequency"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.frequencyLabel(root.detailAp)
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Gateway"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) && root.activeStatus && root.activeStatus.ip4 && root.activeStatus.ip4.gateway ? root.activeStatus.ip4.gateway : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Security"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.securityLabel(root.detailAp.security)
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Subnet"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) ? root.subnetLabel(root.activeStatus ? root.activeStatus.ip4 : null) : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Network usage"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: "Detect automatically"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "DNS"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    width: 220
                                                    text: root.isActive(root.detailAp) ? root.dnsLabel(root.activeStatus ? root.activeStatus.ip4 : null) : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 145
                                    radius: 10
                                    color: "#0b1320"
                                    border.color: "#1f2a3a"

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Text {
                                            text: "Network details"
                                            color: "#e5e7eb"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        Grid {
                                            width: parent.width
                                            columns: 2
                                            columnSpacing: 46
                                            rowSpacing: 14
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Type"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.wifiType(root.detailAp)
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Transmit link speed"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) ? root.bitrateLabel() : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "MAC address"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) ? root.macLabel() : (root.detailAp.bssid || "—")
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                            Column {
                                                width: 245
                                                spacing: 3
                                                Text {
                                                    text: "Receive link speed"
                                                    color: "#94a3b8"
                                                    font.pixelSize: 13
                                                }
                                                Text {
                                                    text: root.isActive(root.detailAp) ? root.bitrateLabel() : "—"
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 14
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 58
                                    radius: 10
                                    color: "#0b1320"
                                    border.color: "#1f2a3a"

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        Column {
                                            width: parent.width - 70
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                text: "Auto-connect"
                                                color: "#e5e7eb"
                                                font.pixelSize: 15
                                                font.bold: true
                                            }
                                            Text {
                                                text: root.profileFor(root.detailAp) ? "Allow connection to this network when in range" : "Connect once before autoconnect is available"
                                                color: "#64748b"
                                                font.pixelSize: 12
                                            }
                                        }

                                        Rectangle {
                                            width: 40
                                            height: 22
                                            radius: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.profileFor(root.detailAp) && root.profileFor(root.detailAp).autoconnect ? "#3b82f6" : "#334155"
                                            opacity: root.profileFor(root.detailAp) ? 1.0 : 0.45
                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 8
                                                y: 3
                                                x: root.profileFor(root.detailAp) && root.profileFor(root.detailAp).autoconnect ? 21 : 3
                                                color: "#dbeafe"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.toggleAutoconnectSelected()
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    height: 20
                                    Text {
                                        text: root.isActive(root.detailAp) && root.activeStatus && root.activeStatus.active_since_ms ? "Connected" : ""
                                        color: "#64748b"
                                        font.pixelSize: 12
                                    }
                                    Item {
                                        width: parent.width - 170
                                        height: 1
                                    }
                                    Text {
                                        text: root.detailAp.last_seen >= 0 ? "Last seen: just now" : ""
                                        color: "#64748b"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Text {
                                visible: !root.hasSelection
                                anchors.centerIn: parent
                                text: "Select a network"
                                color: "#94a3b8"
                                font.pixelSize: 22
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.promptOpen
                anchors.fill: parent
                z: 10
                color: "#99000000"

                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    width: Math.min(parent.width - 80, 560)
                    height: 230
                    anchors.centerIn: parent
                    radius: 16
                    color: "#0f172a"
                    border.color: "#38bdf8"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        Text {
                            width: parent.width
                            text: root.promptTitle
                            color: "#f8fafc"
                            font.pixelSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.promptDetail
                            color: "#94a3b8"
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        TextInput {
                            id: promptInput
                            width: parent.width
                            height: 44
                            color: "#e5e7eb"
                            selectionColor: "#2563eb"
                            selectedTextColor: "white"
                            font.pixelSize: 19
                            text: root.promptText
                            echoMode: root.promptPassword ? TextInput.Password : TextInput.Normal
                            onTextChanged: root.promptText = text
                            Keys.onPressed: function (event) {
                                if (root.isEnterKey(event.key))
                                    return root.acceptKey(event, root.submitPrompt);
                                if (event.key === Qt.Key_Escape)
                                    return root.acceptKey(event, root.cancelPrompt);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "#111827"
                                border.color: "#334155"
                                z: -1
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Enter continue/connect   •   Esc cancel"
                            color: "#64748b"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
