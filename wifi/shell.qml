import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var networks: []
    property var savedProfiles: []
    property var optionItems: []
    property string filterText: ""
    property int selectedIndex: 0
    property int selectedOptionIndex: 0
    property bool optionsOpen: false
    property string status: "Loading Wi-Fi networks…"
    property bool lastConnectWasOpenNetwork: false
    property string lastConnectedSsid: ""

    readonly property var filteredNetworks: networks.filter(function(ap) {
        return !root.filterText || (ap.ssid || "").toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1;
    })

    function selectedNetwork() {
        if (filteredNetworks.length === 0) return null;
        if (selectedIndex < 0) selectedIndex = 0;
        if (selectedIndex >= filteredNetworks.length) selectedIndex = filteredNetworks.length - 1;
        return filteredNetworks[selectedIndex];
    }

    function sameBytes(left, right) {
        if (!left || !right || left.length !== right.length) return false;
        for (let i = 0; i < left.length; i++) {
            if (left[i] !== right[i]) return false;
        }
        return true;
    }

    function profilesFor(ap) {
        if (!ap) return [];
        const apBytes = ap.ssid_bytes || [];
        return root.savedProfiles.filter(function(profile) {
            const profileBytes = profile.ssid_bytes || [];
            if (apBytes.length > 0 && profileBytes.length > 0) {
                return root.sameBytes(apBytes, profileBytes);
            }
            return (profile.ssid || profile.id || "") === (ap.ssid || "");
        });
    }

    function primaryProfile(ap) {
        const profiles = profilesFor(ap);
        return profiles.length > 0 ? profiles[0] : null;
    }

    function rebuildOptions() {
        const ap = selectedNetwork();
        if (!ap) {
            optionItems = [];
            return;
        }

        const profile = primaryProfile(ap);
        const profiles = profilesFor(ap);
        const items = [
            { label: "Connect", detail: "Attempt connection to this access point", action: "connect", enabled: true },
            { label: "Open captive portal", detail: "Open plain-HTTP login trigger pages", action: "portal", enabled: true },
            { label: "Refresh", detail: "Reload networks and saved profile state", action: "refresh", enabled: true }
        ];

        if (profile) {
            items.push({
                label: profile.autoconnect ? "Disable autoconnect" : "Enable autoconnect",
                detail: profile.id,
                action: "toggle-autoconnect",
                enabled: true,
                profile: profile
            });
            items.push({
                label: "Forget saved profile",
                detail: profile.id,
                action: "forget",
                enabled: true,
                profile: profile,
                destructive: true
            });
            if (profiles.length > 1) {
                items.push({
                    label: profiles.length + " saved profiles match this SSID",
                    detail: "Using first profile: " + profile.id,
                    action: "none",
                    enabled: false
                });
            }
        } else {
            items.push({
                label: "No saved profile",
                detail: "Connect once before autoconnect/forget options are available",
                action: "none",
                enabled: false
            });
        }

        items.push({
            label: "Details",
            detail: (ap.bssid || "no BSSID") + "  •  " + (ap.security === "--" ? "open" : ap.security) + "  •  " + (ap.strength || 0) + "%",
            action: "none",
            enabled: false
        });

        optionItems = items;
        if (selectedOptionIndex < 0) selectedOptionIndex = 0;
        if (selectedOptionIndex >= optionItems.length) selectedOptionIndex = optionItems.length - 1;
    }

    property bool triedCachedList: false

    function refresh() {
        status = "Scanning Wi-Fi networks…";
        triedCachedList = false;
        // NetworkManager may only expose the currently-associated AP until a scan is
        // requested. Scan first, then read the live AP objects so the selected BSSID
        // remains current when Enter connects.
        scanProc.exec(["nm-wifi-rofi", "scan", "--cache", "--timeout", "10"]);
        refreshSavedProfiles();
    }

    function refreshSavedProfiles() {
        savedListProc.exec(["nm-wifi-rofi", "saved", "--json"]);
    }

    function openOptions() {
        if (!selectedNetwork()) return;
        optionsOpen = true;
        selectedOptionIndex = 0;
        rebuildOptions();
    }

    function closeOptions() {
        optionsOpen = false;
    }

    function connectSelected() {
        const ap = selectedNetwork();
        if (!ap) return;
        status = "Connecting to " + ap.ssid + "…";
        lastConnectWasOpenNetwork = ap.security === "--";
        lastConnectedSsid = ap.ssid || "";
        const command = ["nm-wifi-rofi", "connect", ap.ssid];
        if (ap.bssid) {
            command.push("--bssid");
            command.push(ap.bssid);
        }
        connectProc.exec(command);
    }

    function executeOption(option) {
        if (!option || !option.enabled) return;
        if (option.action === "connect") {
            connectSelected();
        } else if (option.action === "portal") {
            status = "Opening captive portal pages…";
            portalProc.exec(["shelllist-captive-portal"]);
        } else if (option.action === "refresh") {
            refresh();
        } else if (option.action === "toggle-autoconnect" && option.profile) {
            const enabled = !option.profile.autoconnect;
            status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + option.profile.id + "…";
            profileProc.exec(["nm-wifi-rofi", "profile", "autoconnect", option.profile.path, enabled ? "true" : "false"]);
        } else if (option.action === "forget" && option.profile) {
            status = "Forgetting saved profile " + option.profile.id + "…";
            profileProc.exec(["nm-wifi-rofi", "profile", "delete", option.profile.path]);
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: scanProc
        stdout: StdioCollector { id: scanOut; waitForEnd: true }
        stderr: StdioCollector { id: scanErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.status = "Loading scanned Wi-Fi networks…";
            } else {
                root.status = "Scan failed; loading current NetworkManager list…";
            }
            listProc.exec(["nm-wifi-rofi", "list", "--json"]);
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            id: listOut
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.networks = JSON.parse(text);
                    root.selectedIndex = 0;
                    root.status = root.networks.length + " networks available";
                    if (root.optionsOpen) root.rebuildOptions();
                } catch (error) {
                    root.status = "Could not parse nm-wifi-rofi list output: " + error;
                }
            }
        }
        stderr: StdioCollector { id: listErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && !root.triedCachedList) {
                root.triedCachedList = true;
                root.status = "Live list failed; trying cached list…";
                listProc.exec(["nm-wifi-rofi", "list", "--cached", "--json"]);
            } else if (exitCode !== 0) {
                root.status = "List failed: " + listErr.text;
            }
        }
    }

    Process {
        id: savedListProc
        stdout: StdioCollector {
            id: savedListOut
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.savedProfiles = JSON.parse(text);
                    if (root.optionsOpen) root.rebuildOptions();
                } catch (error) {
                    root.status = "Could not parse saved profiles: " + error;
                }
            }
        }
        stderr: StdioCollector { id: savedListErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Saved profile list failed: " + savedListErr.text;
            }
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector { id: connectOut; waitForEnd: true }
        stderr: StdioCollector { id: connectErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.status = "Connected to " + root.lastConnectedSsid + "; checking captive portal…";
                connectivityCheckTimer.restart();
                if (root.lastConnectWasOpenNetwork) {
                    // Open networks in cafes/hotels/shops often need a portal even
                    // before NetworkManager has classified connectivity as portal.
                    portalProc.exec(["shelllist-captive-portal"]);
                }
                root.refresh();
            } else {
                root.status = "Connect failed: " + connectErr.text;
            }
        }
    }

    Process {
        id: profileProc
        stdout: StdioCollector { id: profileOut; waitForEnd: true }
        stderr: StdioCollector { id: profileErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.status = "Saved profile updated";
                root.refreshSavedProfiles();
            } else {
                root.status = "Profile action failed: " + profileErr.text;
            }
        }
    }

    Timer {
        id: connectivityCheckTimer
        interval: 2500
        repeat: false
        onTriggered: connectivityProc.exec(["nmcli", "networking", "connectivity", "check"])
    }

    Process {
        id: connectivityProc
        stdout: StdioCollector { id: connectivityOut; waitForEnd: true }
        stderr: StdioCollector { id: connectivityErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            const state = connectivityOut.text.trim();
            if (state === "portal" || state === "limited") {
                root.status = "Captive portal detected for " + root.lastConnectedSsid + "; opening login pages…";
                portalProc.exec(["shelllist-captive-portal"]);
            } else if (state === "full") {
                root.status = "Connected to " + root.lastConnectedSsid + " with full connectivity";
            } else if (state.length > 0) {
                root.status = "Connected to " + root.lastConnectedSsid + "; connectivity: " + state;
            }
        }
    }

    Process {
        id: portalProc
        stdout: StdioCollector { waitForEnd: false }
        stderr: StdioCollector { id: portalErr; waitForEnd: false }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && portalErr.text.length > 0) {
                root.status = "Could not open captive portal browser: " + portalErr.text;
            }
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
                    Keys.onPressed: function(event) {
                        if (root.optionsOpen) {
                            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left) {
                                root.closeOptions();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                root.selectedOptionIndex = Math.min(root.selectedOptionIndex + 1, root.optionItems.length - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.selectedOptionIndex = Math.max(root.selectedOptionIndex - 1, 0);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.executeOption(root.optionItems[root.selectedOptionIndex]);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_F5) {
                                root.refresh();
                                event.accepted = true;
                            }
                            return;
                        }

                        if (event.key === Qt.Key_Escape) {
                            Qt.quit();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredNetworks.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            root.openOptions();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.connectSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_F5) {
                            root.refresh();
                            event.accepted = true;
                        }
                    }

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
                    text: root.status + "   •   Enter connect   •   Right options   •   Left close options   •   F5 refresh   •   Esc close"
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

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 42
                            radius: 8
                            color: index === root.selectedIndex ? "#2563eb" : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    width: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.active ? "●" : " "
                                    color: modelData.active ? "#22c55e" : "#94a3b8"
                                    font.pixelSize: 18
                                }

                                Text {
                                    width: 54
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (modelData.strength || 0) + "%"
                                    color: "#dbeafe"
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: 17
                                }

                                Text {
                                    width: 48
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.security === "--" ? "open" : modelData.security
                                    color: modelData.security === "--" ? "#fbbf24" : "#cbd5e1"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.ssid || "<hidden>"
                                    color: "#f8fafc"
                                    font.pixelSize: 18
                                    elide: Text.ElideRight
                                    width: parent.width - 160
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    root.selectedIndex = index;
                                    if (mouse.button === Qt.RightButton) root.openOptions();
                                    else if (root.optionsOpen) root.rebuildOptions();
                                }
                                onDoubleClicked: root.connectSelected()
                            }
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
                                    return ap ? (ap.ssid || "<hidden>") : "Network options";
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

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 58
                                    radius: 8
                                    color: index === root.selectedOptionIndex ? "#92400e" : "transparent"
                                    border.color: modelData.destructive ? "#7f1d1d" : "transparent"
                                    border.width: modelData.destructive ? 1 : 0
                                    opacity: modelData.enabled ? 1.0 : 0.55

                                    Column {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: modelData.label
                                            color: modelData.destructive ? "#fecaca" : "#e5e7eb"
                                            font.pixelSize: 16
                                            font.bold: modelData.enabled
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.detail || ""
                                            color: "#94a3b8"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.selectedOptionIndex = index
                                        onDoubleClicked: root.executeOption(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
