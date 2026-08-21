import QtQuick
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane

    required property ApplicationController controller
    readonly property var selected: controller.selectedResult || ({})
    readonly property var application: controller.selectedApplication || ({})
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight

    chooserController: controller
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select an application"
    headerHeight: Math.max(58, Math.round(66 * uiScale))
    controlHeight: actionHeight
    icon: "󰀻"
    iconColor: application.focused ? Ui.Theme.active : Ui.Theme.accent
    title: selected.title || "Application"
    subtitle: selected.subtitle || ""
    actions: controller.detailActions || []
    actionWidth: 128
    onActionTriggered: function (actionId) { controller.triggerDetailAction(actionId); }

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.footerHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: pane.application.kind === "desktop-shortcut"
            ? [{ value: "application", icon: "󰀻", label: "Shortcut" }]
            : pane.application.kind === "desktop-application"
                ? [
                    { value: "application", icon: "󰀻", label: "Application" },
                    { value: "resources", icon: "󰄪", label: "Resources" },
                    { value: "categories", icon: "󰉋", label: "Categories" },
                    { value: "settings", icon: "󰒓", label: "Settings" }
                ]
                : [
                    { value: "application", icon: "󰀻", label: "Window" },
                    { value: "resources", icon: "󰄪", label: "Resources" }
                ]
        onSelected: function (value) { pane.controller.selectDetailsTab(value); }

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

        ApplicationCategoryPage {
            anchors.fill: parent
            visible: pane.controller.detailsTab === "categories"
            controller: pane.controller
            application: pane.application
        }

        ApplicationSettingsPage {
            anchors.fill: parent
            visible: pane.controller.detailsTab === "settings"
            controller: pane.controller
            application: pane.application
        }
    }
}
