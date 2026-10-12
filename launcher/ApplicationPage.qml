import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    objectName: "applicationPage"
    viewMemory: controller.viewMemory
    memoryTab: "application"
    cardSpacing: Ui.Theme.cardGap

    required property ApplicationController controller
    required property var application
    required property real uiScale

    Ui.ThemeText {
        objectName: "applicationDescription"
        visible: !!page.application.comment && page.application.comment !== (page.controller.selectedResult || {}).subtitle
        width: parent.width
        text: page.application.comment || ""
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
    }

    Ui.ContentState {
        objectName: "applicationEmptyState"
        visible: page.application.kind === "desktop-shortcut" || (page.application.instances || []).length === 0
        width: parent.width
        height: Math.max(112 * page.uiScale, implicitHeight + Ui.Theme.spacingXxl)
        compact: true
        uiScale: page.uiScale
        icon: page.application.kind === "desktop-shortcut" ? "open_in_new" : "web_asset_off"
        showLabel: false
        text: page.application.kind === "desktop-shortcut" ? qsTr("This shortcut opens content in another application") : page.application.kind === "desktop-application" ? qsTr("No open windows\nUse Launch beside the application name to get started.") : qsTr("Window is no longer available")
        Rectangle {
            anchors.fill: parent
            z: -1
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surfaceContainer
        }
    }

    ApplicationInstanceList {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    ApplicationDataDetails {
        width: parent.width
        controller: page.controller
        application: page.application
    }

    ApplicationDesktopActions {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    Ui.ContentState {
        id: noActions
        objectName: "applicationNoActions"
        visible: page.application.kind === "desktop-application" && (page.application.desktop_actions || []).length === 0
        width: parent.width
        // Center the passive mark in the space below app data; short pages scroll.
        height: Math.max(implicitHeight + Ui.Theme.spacingXxl, page.height - noActions.y)
        compact: true
        uiScale: page.uiScale
        icon: "extension_off"
        showLabel: false
        text: qsTr("No additional actions provided by this application.")
    }

}
