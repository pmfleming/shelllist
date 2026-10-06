pragma ComponentBehavior: Bound

import Quickshell
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
    controlHeight: actionHeight
    icon: "󰀻"
    iconSource: Quickshell.iconPath(application.icon || "application-x-executable", "application-x-executable")
    iconColor: Ui.Theme.accent
    iconBorderColor: "transparent"
    title: selected.title || "Application"
    subtitle: application.kind === "desktop-shortcut" ? qsTr("Opens in another application") : (application.instances || []).length === 1 ? qsTr("1 open window") : (application.instances || []).length > 1 ? qsTr("%1 open windows").arg(application.instances.length) : application.kind === "desktop-application" ? qsTr("Not running") : qsTr("Window is no longer available")
    actions: controller.detailActions || []

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.footerHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: [
            {
                value: "application",
                icon: "󰀻",
                label: ({
                        "desktop-shortcut": "Shortcut",
                        "desktop-application": "Application"
                    })[pane.application.kind] || "Window"
            },
            {
                value: "resources",
                icon: "󰄪",
                label: "Resources"
            },
            {
                value: "settings",
                icon: "󰒓",
                label: "Settings"
            }
        ].filter(tab => pane.controller.availableDetailsTabs().includes(tab.value))
        onSelected: function (value) {
            pane.controller.selectDetailsTab(value);
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "application"
            asynchronous: true
            sourceComponent: ApplicationPage {
                controller: pane.controller
                application: pane.application
                uiScale: pane.uiScale
                actionHeight: pane.actionHeight
            }
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "resources"
            asynchronous: true
            sourceComponent: ApplicationResourcesPage {
                controller: pane.controller
                application: pane.application
                uiScale: pane.uiScale
            }
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "settings"
            asynchronous: true
            sourceComponent: ApplicationSettingsPage {
                controller: pane.controller
                application: pane.application
            }
        }
    }
}
