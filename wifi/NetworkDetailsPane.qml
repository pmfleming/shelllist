import QtQuick
import "."
import Shelllist.Ui

DetailsPane {
    id: pane

    required property WifiController controller
    readonly property var ap: controller.detailAp
    readonly property real uiScale: Theme.densityScale(height, 0)
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int detailControlHeight: Math.max(36, Math.round(42 * uiScale))
    readonly property int footerHeight: detailControlHeight
    readonly property real cardBudget: Math.max(420, height - 2 - actionHeader.height - footerHeight - 4 * sectionSpacing)
    readonly property real connectionCardHeight: Math.max(220, Math.round(cardBudget * 0.44))
    readonly property real networkCardHeight: Math.max(130, Math.round(cardBudget * 0.255))
    readonly property real profileCardHeight: Math.max(150, cardBudget - connectionCardHeight - networkCardHeight)

    chooserController: controller
    densityScale: uiScale
    sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, uiScale)
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select a network"
    emptyFontSize: 20

    NetworkDetailsHeader {
        id: actionHeader
        width: parent.width
        controller: pane.controller
        uiScale: pane.uiScale
        headerHeight: pane.headerHeight
        controlHeight: pane.detailControlHeight
        sectionSpacing: pane.sectionSpacing
    }

    Item {
        id: tabViewport

        property real advancedTransitionProgress: pane.controller.advanced.open ? 1 : 0

        width: parent.width
        height: Math.max(0, parent.height - actionHeader.height - pane.footerHeight - 2 * pane.sectionSpacing)
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
