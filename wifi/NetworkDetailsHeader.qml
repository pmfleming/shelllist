import QtQuick
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

DetailsHeader {
    id: header

    required property WifiController controller
    readonly property var ap: controller.detailAp
    readonly property string connectionLabel: Presentation.connectionStateLabel(controller, ap)
    readonly property bool signInRequired: Presentation.connectivityRequiresSignIn(Presentation.activeConnectivity(controller))
    readonly property color connectionColor: signInRequired ? Theme.warning : Theme.active
    readonly property string lastSeenLabel: Presentation.lastSeenLabel(ap)

    signalIcon: true
    iconColor: Theme.accent
    title: Presentation.networkName(ap)
    subtitle: [connectionLabel, lastSeenLabel].filter(function (value) { return value.length > 0; }).join(" / ")
    subtitleColor: controller.isActive(ap) ? connectionColor : Theme.mutedText
    statusIndicatorVisible: controller.isActive(ap)
    statusIndicatorColor: connectionColor
    titlePixelSize: Math.round(22 * uiScale)
    subtitleWeight: Theme.fontWeightMedium
    actions: controller.detailActions
    actionWidth: 156
    onActionTriggered: function (actionId) { header.controller.triggerDetailAction(actionId); }
}
