import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.DetailsPane {
    id: pane

    required property ApplicationController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property var application: controller.selectedApplication || ({})
    readonly property var actions: controller.detailActions || []
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))

    chooserController: controller
    densityScale: uiScale
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select an application"

    Ui.DetailsHeader {
        id: actionHeader
        width: parent.width
        uiScale: pane.uiScale
        headerHeight: pane.headerHeight
        controlHeight: pane.actionHeight
        sectionSpacing: pane.sectionSpacing
        icon: "󰀻"
        iconColor: pane.application.focused ? Ui.Theme.active : Ui.Theme.accent
        title: pane.selected.title || "Application"
        subtitle: pane.selected.subtitle || ""
        titlePixelSize: Math.round(Ui.Theme.fontSizeTitle * pane.uiScale)
        actions: pane.actions
        actionWidth: 128
        onActionTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
    }

    Ui.DetailFlickable {
        width: parent.width
        height: Math.max(0, parent.height - actionHeader.height - pane.sectionSpacing)

        Text {
            visible: pane.application.comment && pane.application.comment.length > 0
            width: parent.width
            text: pane.application.comment || ""
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }

        Text {
            visible: pane.application.running
            width: parent.width
            text: "Total usage · " + Presentation.usageText(pane.application)
            color: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        ApplicationResourceHistory {
            visible: pane.application.running
            width: parent.width
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
        }

        ApplicationInstanceList {
            width: parent.width
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
            actionHeight: pane.actionHeight
        }

        ApplicationDesktopActions {
            width: parent.width
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
        }

        Ui.CenteredMessage {
            visible: (pane.application.instances || []).length === 0
                && (pane.application.desktop_actions || []).length === 0
            width: parent.width
            height: 120
            text: pane.application.kind === "desktop-application"
                ? "No additional actions"
                : "Window is no longer available"
            font.pixelSize: Ui.Theme.fontSizeBody
        }
    }
}
