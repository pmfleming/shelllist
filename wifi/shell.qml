import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var networks: []
    property string filterText: ""
    property int selectedIndex: 0
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

    property bool triedCachedList: false

    function refresh() {
        status = "Loading live Wi-Fi networks…";
        triedCachedList = false;
        // Use live NetworkManager AP objects, not the rofi cache, so selected BSSID/AP path
        // is current when Enter connects. The cache can be minutes stale in busy areas.
        listProc.exec(["nm-wifi-rofi", "list", "--json"]);
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

    Component.onCompleted: refresh()

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
        implicitWidth: 900
        implicitHeight: 720
        title: "Shelllist Wi-Fi"
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#151821"
            border.color: "#3b82f6"
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
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            Qt.quit();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredNetworks.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
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
                        border.color: "#334155"
                        z: -1
                    }
                }

                Text {
                    width: parent.width
                    text: root.status + "   •   Enter connect   •   Up/Down select   •   F5 refresh   •   Esc close"
                    color: "#94a3b8"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - 160
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
                            onClicked: root.selectedIndex = index
                            onDoubleClicked: root.connectSelected()
                        }
                    }
                }
            }
        }
    }
}
