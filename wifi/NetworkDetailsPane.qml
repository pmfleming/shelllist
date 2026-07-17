import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
import "."

Rectangle {
    id: pane

    required property var controller
    readonly property var ap: controller.detailAp
    readonly property string connectionLabel: Wifi.connectionStateLabel(controller, ap)
    readonly property bool signInRequired: Wifi.connectivityRequiresSignIn(Wifi.activeConnectivity(controller))
    readonly property color connectionColor: signInRequired ? Theme.warning : Theme.active
    readonly property string lastSeenLabel: Wifi.lastSeenLabel(ap)
    readonly property real uiScale: Math.max(0.82, Math.min(1.12, height / 850))
    readonly property int sectionSpacing: Math.max(8, Math.round(12 * uiScale))
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int detailControlHeight: Math.max(36, Math.round(42 * uiScale))
    readonly property int actionsHeight: detailControlHeight
    readonly property int footerHeight: detailControlHeight
    readonly property real cardBudget: Math.max(420, height - 2 - headerHeight - actionsHeight - footerHeight - 5 * sectionSpacing)
    readonly property real connectionCardHeight: Math.round(cardBudget * 0.44)
    readonly property real networkCardHeight: Math.round(cardBudget * 0.255)
    readonly property real profileCardHeight: Math.max(0, cardBudget - connectionCardHeight - networkCardHeight)

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 0
    color: "transparent"
    border.color: "transparent"
    clip: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        anchors.bottomMargin: 2

        Column {
            visible: pane.controller.hasSelection
            anchors.fill: parent
            spacing: pane.sectionSpacing

            RowLayout {
                width: parent.width
                height: pane.headerHeight
                spacing: 14

                Item {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 54
                    Layout.alignment: Qt.AlignVCenter

                    SignalIcon {
                        anchors.centerIn: parent
                        width: Math.round(48 * pane.uiScale)
                        height: Math.round(40 * pane.uiScale)
                        level: 3
                        iconColor: Theme.accent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 7

                    Text {
                        width: parent.width
                        text: Wifi.networkName(pane.ap)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(22 * pane.uiScale)
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Row {
                        height: 18
                        spacing: 8

                        Rectangle {
                            visible: pane.controller.isActive(pane.ap)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: width / 2
                            color: pane.connectionColor
                        }

                        Text {
                            visible: pane.connectionLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: pane.connectionLabel
                            color: pane.controller.isActive(pane.ap) ? pane.connectionColor : Theme.mutedText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Text {
                            visible: pane.connectionLabel.length > 0 && pane.lastSeenLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "/"
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            visible: pane.lastSeenLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: pane.lastSeenLabel
                            color: Theme.mutedText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 156
                    Layout.preferredHeight: pane.detailControlHeight
                    Layout.alignment: Qt.AlignVCenter

                    NetworkDetailsActions {
                        anchors.fill: parent
                        controller: pane.controller
                        primaryOnly: true
                        alignRight: true
                        controlHeight: pane.detailControlHeight
                    }
                }
            }

            NetworkDetailsActions {
                controller: pane.controller
                primaryOnly: false
                alignRight: true
                controlHeight: pane.detailControlHeight
                width: parent.width
                height: pane.actionsHeight
            }

            Item {
                width: parent.width
                height: Math.max(0, parent.height - pane.headerHeight - pane.actionsHeight - pane.footerHeight - 3 * parent.spacing)
                clip: true

                Column {
                    enabled: !pane.controller.advancedOpen
                    width: parent.width
                    height: parent.height
                    x: pane.controller.advancedOpen ? -width : 0
                    spacing: pane.sectionSpacing

                    Behavior on x {
                        enabled: !Theme.noAnimations
                        NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
                    }

                    DetailCard {
                        height: pane.connectionCardHeight
                        title: "Connection"

                        DetailGrid {
                            entries: Wifi.connectionDetailRows(pane.controller, pane.ap, Theme.accent).slice(0, 8)
                        }
                    }

                    DetailCard {
                        height: pane.networkCardHeight
                        title: "Network details"

                        DetailGrid {
                            entries: Wifi.networkDetailRows(pane.controller, pane.ap).slice(0, 4)
                        }
                    }

                    NetworkProfileSettingsCard {
                        controller: pane.controller
                        height: pane.profileCardHeight
                    }
                }

                AdvancedSettingsPage {
                    enabled: pane.controller.advancedOpen
                    width: parent.width
                    height: parent.height
                    x: pane.controller.advancedOpen ? 0 : width
                    controller: pane.controller
                    sectionSpacing: pane.sectionSpacing

                    Behavior on x {
                        enabled: !Theme.noAnimations
                        NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
                    }
                }
            }

            Item {
                width: parent.width
                height: pane.footerHeight

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰋜"
                        label: "Network Details"
                        selected: pane.controller.detailsTab === "network"
                        onClicked: pane.controller.selectDetailsTab("network")
                    }

                    DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰌾"
                        label: "Security & Privacy"
                        selected: pane.controller.detailsTab === "security"
                        enabled: !!pane.controller.profileFor(pane.ap)
                        onClicked: pane.controller.selectDetailsTab("security")
                    }

                    DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰍹"
                        label: "IP & DNS"
                        selected: pane.controller.detailsTab === "hardware"
                        enabled: !!pane.controller.profileFor(pane.ap)
                        onClicked: pane.controller.selectDetailsTab("hardware")
                    }
                }
            }
        }

        CenteredMessage {
            visible: !pane.controller.hasSelection
            text: "Select a network"
            font.pixelSize: 20
        }
    }
}
