pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

ActionDetailsPane {
    id: pane

    required property WifiController controller
    readonly property var ap: controller.detailAp
    readonly property int detailControlHeight: Math.max(36, Math.round(42 * uiScale))
    readonly property int footerHeight: detailControlHeight
    readonly property string connectionLabel: Presentation.connectionStateLabel(controller, ap)
    readonly property bool signInRequired: Presentation.connectivityRequiresSignIn(
        Presentation.activeConnectivity(controller))
    readonly property color connectionColor: signInRequired ? Theme.warning : Theme.active
    readonly property real cardBudget: Math.max(420,
        bodyHeight - footerHeight - 3 * sectionSpacing - 2)
    readonly property real connectionCardHeight: Math.max(220, Math.round(cardBudget * 0.44))
    readonly property real networkCardHeight: Math.max(130, Math.round(cardBudget * 0.255))
    readonly property real profileCardHeight: Math.max(150, cardBudget - connectionCardHeight - networkCardHeight)

    chooserController: controller
    uiScale: Theme.densityScale(height, 0)
    sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, uiScale)
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select a network"
    emptyFontSize: 20
    headerHeight: Math.max(56, Math.round(64 * uiScale))
    controlHeight: detailControlHeight
    signalIcon: true
    iconColor: Theme.accent
    title: Presentation.networkName(ap)
    subtitle: [connectionLabel, Presentation.lastSeenLabel(ap)].filter(function (value) {
        return value.length > 0;
    }).join(" / ")
    subtitleColor: controller.isActive(ap) ? connectionColor : Theme.mutedText
    statusIndicatorVisible: controller.isActive(ap)
    statusIndicatorColor: connectionColor
    titlePixelSize: Math.round(22 * uiScale)
    subtitleWeight: Theme.fontWeightMedium
    actions: controller.detailActions
    actionWidth: 156
    onActionTriggered: function (actionId) { controller.triggerDetailAction(actionId); }

    Item {
        id: tabViewport

        property real advancedTransitionProgress: pane.controller.advanced.open
            && advancedLoader.status === Loader.Ready ? 1 : 0

        width: parent.width
        height: Math.max(0, parent.height - pane.footerHeight - pane.sectionSpacing)
        clip: true

        Behavior on advancedTransitionProgress {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationInteractive
                easing.type: Theme.easingResponsive
            }
        }

        NetworkDetailCards {
            enabled: !pane.controller.advanced.open
                || advancedLoader.status !== Loader.Ready
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

        Loader {
            id: advancedLoader

            active: pane.controller.advanced.open
                || tabViewport.advancedTransitionProgress > 0
            asynchronous: true
            enabled: pane.controller.advanced.open
            width: parent.width
            height: parent.height
            x: width * (1 - tabViewport.advancedTransitionProgress)
            sourceComponent: Component {
                AdvancedSettingsPage {
                    controller: pane.controller
                    sectionSpacing: pane.sectionSpacing
                }
            }
        }

        PulsingLabel {
            anchors.centerIn: parent
            visible: pane.controller.advanced.open
                && advancedLoader.status === Loader.Loading
            text: "Loading advanced settings…"
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }
    }

    DetailsTabBar {
        anchors.bottom: parent.bottom
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
