pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane

    required property ApplicationController controller
    readonly property var selected: controller.selectedResult || ({})
    readonly property var application: controller.selectedApplication || ({})

    chooserController: controller
    emptyText: "Select an application"
    icon: "󰀻"
    iconSource: Quickshell.iconPath(application.icon || "application-x-executable", "application-x-executable")
    iconColor: Ui.Theme.accent
    iconBorderColor: "transparent"
    title: selected.title || "Application"
    subtitle: application.kind === "desktop-shortcut" ? qsTr("Opens in another application") : (application.instances || []).length === 1 ? qsTr("1 open window") : (application.instances || []).length > 1 ? qsTr("%1 open windows").arg(application.instances.length) : application.kind === "desktop-application" ? qsTr("Not running") : qsTr("Window is no longer available")
    // Window and desktop actions live only on the Application page, including
    // its shared Alt+J command menu; do not duplicate them in header overflow.
    actions: (controller.detailActions || []).filter(action => action.presentation.group === "primary" || action.presentation.group === "toolbar")

    // Action progress/outcomes belong to the fixed list status bar on every tab.
    Ui.FeedbackSource {
        text: pane.controller.selectedActionMessage
        briefText: pane.controller.operations.busy(pane.selected.id || "")
            ? qsTr("Application action pending") : qsTr("Application action outcome available")
    }

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.controlHeight
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
            asynchronous: true
            active: sourceComponent !== null
            sourceComponent: pane.controller.detailsTab === "application" ? applicationPage
                : pane.controller.detailsTab === "resources" ? resourcesPage
                : pane.controller.detailsTab === "settings" ? settingsPage : null
        }
    }

    Component {
        id: applicationPage
        ApplicationPage {
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
        }
    }
    Component {
        id: resourcesPage
        ApplicationResourcesPage {
            controller: pane.controller
            application: pane.application
            uiScale: pane.uiScale
        }
    }
    Component {
        id: settingsPage
        ApplicationSettingsPage {
            controller: pane.controller
            application: pane.application
        }
    }
}
