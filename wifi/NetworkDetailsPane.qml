import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

Rectangle {
    id: pane

    required property WifiController controller
    readonly property var ap: controller.detailAp
    readonly property real uiScale: Theme.densityScale(height, 0)
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

            NetworkDetailsHeader {
                width: parent.width
                height: pane.headerHeight
                controller: pane.controller
                uiScale: pane.uiScale
                controlHeight: pane.detailControlHeight
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
                id: tabViewport

                property real advancedTransitionProgress: pane.controller.advanced.open ? 1 : 0

                width: parent.width
                height: Math.max(0, parent.height - pane.headerHeight - pane.actionsHeight - pane.footerHeight - 3 * parent.spacing)
                clip: true

                Behavior on advancedTransitionProgress {
                    enabled: !Theme.noAnimations
                    NumberAnimation { duration: Theme.animationSlow; easing.type: Theme.easingStandard }
                }

                NetworkDetailCards {
                    enabled: !pane.controller.advanced.open
                    width: parent.width
                    height: parent.height
                    x: -width * tabViewport.advancedTransitionProgress
                    controller: pane.controller
                    accessPoint: pane.ap
                    sectionSpacing: pane.sectionSpacing
                    connectionCardHeight: pane.connectionCardHeight
                    networkCardHeight: pane.networkCardHeight
                    profileCardHeight: pane.profileCardHeight
                }

                AdvancedSettingsPage {
                    enabled: pane.controller.advanced.open
                    width: parent.width
                    height: parent.height
                    x: width * (1 - tabViewport.advancedTransitionProgress)
                    controller: pane.controller
                    sectionSpacing: pane.sectionSpacing
                }
            }

            DetailsTabBar {
                width: parent.width
                height: pane.footerHeight
                selectedValue: pane.controller.detailsTab
                tabs: [
                    { value: "network", icon: "󰋜", label: "Network Details" },
                    { value: "security", icon: "󰌾", label: "Security & Privacy", enabled: !!pane.controller.profileFor(pane.ap) },
                    { value: "hardware", icon: "󰍹", label: "IP & DNS", enabled: !!pane.controller.profileFor(pane.ap) }
                ]
                onSelected: function (value) { pane.controller.selectDetailsTab(value); }
            }
        }

        CenteredMessage {
            visible: !pane.controller.hasSelection
            text: "Select a network"
            font.pixelSize: 20
        }
    }
}
