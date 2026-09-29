pragma ComponentBehavior: Bound

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
    inlineActions: true

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
