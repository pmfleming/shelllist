import Quickshell
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: root

    property var networks: []
    property var optionItems: []
    property string filterText: ""
    property int selectedIndex: 0
    property int selectedOptionIndex: 0
    property bool optionsOpen: false
    property string status: "Loading Wi-Fi networks…"
    property string lastConnectedSsid: ""
    property bool scanSnapshotSeen: false

    readonly property string helpText: "Enter connect   •   Right options   •   Left close options   •   F5 refresh   •   Esc close"
    readonly property var filteredNetworks: networks.filter(function(ap) {
        return !root.filterText || (ap.ssid || "").toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1;
    })

    function clampIndex(index, length) {
        return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1));
    }

    function selectedNetwork() {
        if (filteredNetworks.length === 0) return null;
        selectedIndex = clampIndex(selectedIndex, filteredNetworks.length);
        return filteredNetworks[selectedIndex];
    }

    function networkName(ap) {
        return ap && ap.ssid ? ap.ssid : "<hidden>";
    }

    function canConnect(ap) {
        if (!ap) return false;
        if (ap.capabilities) return ap.capabilities.can_connect;
        return !!(ap.ssid && ap.ssid.length > 0);
    }

    function sameAccessPoint(left, right) {
        return (left.bssid && right.bssid === left.bssid)
            || ((left.ssid || "") === (right.ssid || "") && (left.security || "") === (right.security || ""));
    }

    function applyNetworks(newNetworks, resetSelection) {
        const previous = selectedNetwork();
        networks = newNetworks;

        if (resetSelection || !previous) {
            selectedIndex = 0;
        } else {
            const nextIndex = filteredNetworks.findIndex(function(ap) { return sameAccessPoint(previous, ap); });
            selectedIndex = nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, filteredNetworks.length);
        }

        if (optionsOpen) rebuildOptions();
    }

    function option(label, detail, action, enabled, extra) {
        const item = { label: label, detail: detail, action: action, enabled: enabled !== false };
        if (extra) Object.keys(extra).forEach(function(key) { item[key] = extra[key]; });
        return item;
    }

    function setOptions(items) {
        optionItems = items;
        selectedOptionIndex = clampIndex(selectedOptionIndex, optionItems.length);
    }

    function rebuildOptions() {
        const ap = selectedNetwork();
        if (!ap) return setOptions([]);

        const profiles = ap.profiles || [];
        const profile = ap.primary_profile || (profiles.length > 0 ? profiles[0] : null);
        const connectable = canConnect(ap);
        const connectDetail = connectable
            ? "Attempt connection to this access point"
            : (ap.capabilities && ap.capabilities.needs_password)
                ? "Password entry is not implemented in Shelllist yet"
                : "This access point cannot be connected from Shelllist yet";
        const items = [
            option("Connect", connectDetail, "connect", connectable),
            option("Open captive portal", "Open plain-HTTP login trigger pages", "portal"),
            option("Refresh", "Reload networks and saved profile state", "refresh")
        ];

        if (profile) {
            items.push(option(profile.autoconnect ? "Disable autoconnect" : "Enable autoconnect", profile.id, "toggle-autoconnect", true, { profile: profile }));
            items.push(option("Forget saved profile", profile.id, "forget", true, { profile: profile, destructive: true }));
            if (profiles.length > 1) items.push(option(profiles.length + " saved profiles match this SSID", "Using first profile: " + profile.id, "none", false));
        } else {
            items.push(option("No saved profile", "Connect once before autoconnect/forget options are available", "none", false));
        }

        items.push(option("Details", (ap.bssid || "no BSSID") + "  •  " + (ap.security === "--" ? "open" : ap.security) + "  •  " + (ap.strength || 0) + "%", "none", false));
        setOptions(items);
    }

    function refresh() {
        status = "Loading cached Wi-Fi networks…";
        scanSnapshotSeen = false;
        // Shelllist opens from the backend-owned cache, then starts a backend
        // streaming scan that updates this list while the user interacts.
        listProc.exec(["nm-wifi", "networks", "--cached", "--json"]);
        startScanStream();
    }

    function startScanStream() {
        if (!scanStreamProc.running) scanStreamProc.exec(["nm-wifi", "scan", "--stream", "--cache", "--timeout", "12"]);
    }

    function handleScanEvent(line) {
        const trimmed = line.trim();
        if (!trimmed) return;

        try {
            const event = JSON.parse(trimmed);
            const handlers = {
                snapshot: function(e) {
                    scanSnapshotSeen = true;
                    applyNetworks(e.networks || [], false);
                    status = e.networks_found + (e.scanning ? " networks found; scanning…" : " networks available");
                },
                status: function(e) { status = e.message || status; },
                warning: function(e) { status = e.message || status; },
                complete: function(e) { status = e.networks_found + (e.timed_out ? " networks available; scan timed out" : " networks available"); }
            };
            if (handlers[event.event]) handlers[event.event](event);
        } catch (error) {
            status = "Could not parse scan event: " + error;
        }
    }

    function openOptions() {
        if (!selectedNetwork()) return;
        optionsOpen = true;
        selectedOptionIndex = 0;
        rebuildOptions();
    }

    function connectSelected() {
        const ap = selectedNetwork();
        if (!ap) return;
        if (!canConnect(ap)) {
            status = ap.capabilities && ap.capabilities.needs_password
                ? "Password entry is not implemented in Shelllist yet."
                : "This access point cannot be connected from Shelllist yet.";
            return;
        }

        status = "Connecting to " + networkName(ap) + "…";
        lastConnectedSsid = networkName(ap);

        connectProc.exec(["nm-wifi", "connect-target", JSON.stringify(ap), "--json"]);
    }

    function executeOption(item) {
        if (!item || !item.enabled) return;

        const actions = {
            connect: connectSelected,
            portal: function() {
                status = "Opening captive portal pages…";
                portalProc.exec(["shelllist-captive-portal"]);
            },
            refresh: refresh,
            "toggle-autoconnect": function() {
                const enabled = !item.profile.autoconnect;
                status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + item.profile.id + "…";
                profileProc.exec(["nm-wifi", "profile", "autoconnect", item.profile.path, enabled ? "true" : "false"]);
            },
            forget: function() {
                status = "Forgetting saved profile " + item.profile.id + "…";
                profileProc.exec(["nm-wifi", "profile", "delete", item.profile.path]);
            }
        };

        if (actions[item.action]) actions[item.action]();
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

    function moveOption(delta) {
        selectedOptionIndex = clampIndex(selectedOptionIndex + delta, optionItems.length);
    }

    function handleBinding(event, bindings) {
        for (let i = 0; i < bindings.length; i++) {
            if (event.key === bindings[i][0]) return acceptKey(event, bindings[i][1]);
        }
    }

    function handleSearchKey(event) {
        if (optionsOpen) {
            if (isEnterKey(event.key)) return acceptKey(event, function() { executeOption(optionItems[selectedOptionIndex]); });
            return handleBinding(event, [
                [Qt.Key_Escape, function() { optionsOpen = false; }],
                [Qt.Key_Left, function() { optionsOpen = false; }],
                [Qt.Key_Down, function() { moveOption(1); }],
                [Qt.Key_Up, function() { moveOption(-1); }],
                [Qt.Key_F5, refresh]
            ]);
        }

        if (isEnterKey(event.key)) return acceptKey(event, connectSelected);
        return handleBinding(event, [
            [Qt.Key_Escape, Qt.quit],
            [Qt.Key_Down, function() { moveSelection(1); }],
            [Qt.Key_Up, function() { moveSelection(-1); }],
            [Qt.Key_Right, openOptions],
            [Qt.Key_F5, refresh]
        ]);
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (root.scanSnapshotSeen) return;
                    const networks = JSON.parse(text);
                    root.applyNetworks(networks, true);
                    root.status = networks.length + " cached networks; scanning in background…";
                } catch (error) {
                    root.status = "Could not parse nm-wifi networks output: " + error;
                }
            }
        }
        stderr: StdioCollector { id: listErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && !root.scanSnapshotSeen) root.status = "Cached list failed: " + listErr.text;
        }
    }

    Process {
        id: scanStreamProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.handleScanEvent(data); }
        }
        stderr: StdioCollector { id: scanStreamErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && scanStreamErr.text.length > 0) root.status = "Background scan failed: " + scanStreamErr.text;
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector { id: connectOut; waitForEnd: true }
        stderr: StdioCollector { id: connectErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Connect failed: " + connectErr.text;
                return;
            }

            try {
                const result = JSON.parse(connectOut.text);
                const connectivity = result.connectivity || {};
                if (result.suggest_open_portal) {
                    root.status = result.message + "; opening captive portal…";
                    portalProc.exec(["shelllist-captive-portal"]);
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
        id: profileProc
        stderr: StdioCollector { id: profileErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
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
        stderr: StdioCollector { id: portalErr; waitForEnd: false }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && portalErr.text.length > 0) root.status = "Could not open captive portal browser: " + portalErr.text;
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 980
        implicitHeight: 720
        title: "Shelllist Wi-Fi"
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#151821"
            border.color: root.optionsOpen ? "#f59e0b" : "#3b82f6"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                Text {
                    text: "Shelllist Wi-Fi"
                    color: "#e5e7eb"
                    font.pixelSize: 26
                    font.bold: true
                }

                TextInput {
                    id: search
                    width: parent.width
                    height: 42
                    focus: true
                    color: "#e5e7eb"
                    selectionColor: "#2563eb"
                    selectedTextColor: "white"
                    font.pixelSize: 20
                    text: root.filterText
                    onTextChanged: {
                        root.filterText = text;
                        root.selectedIndex = 0;
                        if (root.optionsOpen) root.rebuildOptions();
                    }
                    Keys.onPressed: function(event) { root.handleSearchKey(event); }

                    Rectangle {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 10
                        color: "#0f172a"
                        border.color: root.optionsOpen ? "#f59e0b" : "#334155"
                        z: -1
                    }
                }

                Text {
                    width: parent.width
                    text: root.status + "   •   " + root.helpText
                    color: "#94a3b8"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    height: parent.height - 160
                    spacing: 14

                    ListView {
                        id: list
                        width: root.optionsOpen ? Math.round(parent.width * 0.60) : parent.width
                        height: parent.height
                        clip: true
                        model: root.filteredNetworks
                        spacing: 4

                        delegate: NetworkRow {
                            selectedIndex: root.selectedIndex
                            networkName: root.networkName
                            onPicked: function(rowIndex, open) {
                                root.selectedIndex = rowIndex;
                                if (open) root.openOptions();
                                else if (root.optionsOpen) root.rebuildOptions();
                            }
                            onConnectRequested: root.connectSelected()
                        }
                    }

                    Rectangle {
                        visible: root.optionsOpen
                        width: root.optionsOpen ? parent.width - list.width - parent.spacing : 0
                        height: parent.height
                        radius: 12
                        color: "#0f172a"
                        border.color: "#f59e0b"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                width: parent.width
                                text: {
                                    const ap = root.selectedNetwork();
                                    return ap ? root.networkName(ap) : "Network options";
                                }
                                color: "#f8fafc"
                                font.pixelSize: 20
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: "Enter run option  •  Left close"
                                color: "#94a3b8"
                                font.pixelSize: 13
                            }

                            ListView {
                                id: optionsList
                                width: parent.width
                                height: parent.height - 60
                                clip: true
                                model: root.optionItems
                                spacing: 6

                                delegate: OptionRow {
                                    selectedIndex: root.selectedOptionIndex
                                    onPicked: function(rowIndex) { root.selectedOptionIndex = rowIndex; }
                                    onRunRequested: function(item) { root.executeOption(item); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
