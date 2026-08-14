import QtQuick
import Shelllist.Ui as Ui

Ui.DetailsPane {
    id: pane

    required property ApplicationController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property var application: controller.selectedApplication || ({})
    readonly property var actions: controller.detailActions || []
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight

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

    Item {
        width: parent.width
        height: Math.max(0, parent.height - actionHeader.height
            - pane.footerHeight - 2 * pane.sectionSpacing)
        clip: true

        ApplicationPage {
            anchors.fill: parent
            visible: pane.controller.detailsTab === "application"
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
            actionHeight: pane.actionHeight
        }

        ApplicationResourcesPage {
            anchors.fill: parent
            visible: pane.controller.detailsTab === "resources"
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
        }
    }

    Ui.DetailsTabBar {
        width: parent.width
        height: pane.footerHeight
        selectedValue: pane.controller.detailsTab
        tabs: [
            { value: "application", icon: "󰀻", label: "Application" },
            { value: "resources", icon: "󰄪", label: "Resources" }
        ]
        onSelected: function (value) { pane.controller.selectDetailsTab(value); }
    }
}
