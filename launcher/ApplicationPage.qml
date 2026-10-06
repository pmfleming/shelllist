import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    objectName: "applicationPage"
    viewMemory: controller.viewMemory
    memoryTab: "application"
    cardSpacing: Math.round(Ui.Theme.spacingXl * uiScale)

    required property ApplicationController controller
    required property var application
    required property real uiScale

    Ui.LabeledAction {
        objectName: "applicationActionStatus"
        width: parent.width
        visible: page.controller.selectedActionMessage.length > 0
        label: page.controller.selectedActionMessage
        accessibleName: "Check status"
        icon: "refresh"
        accessKey: "K"
        onClicked: page.controller.operations.check(page.application.id)
    }

    Ui.ThemeText {
        objectName: "applicationDescription"
        visible: !!page.application.comment && page.application.comment !== (page.controller.selectedResult || {}).subtitle
        width: parent.width
        text: page.application.comment || ""
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
    }

    Ui.CenteredMessage {
        objectName: "applicationEmptyState"
        visible: page.application.kind === "desktop-shortcut" || (page.application.instances || []).length === 0
        width: parent.width
        height: Math.max(112, implicitHeight + 32)
        leftPadding: Ui.Theme.spacingLg
        rightPadding: Ui.Theme.spacingLg
        text: page.application.kind === "desktop-shortcut" ? qsTr("This shortcut opens content in another application") : page.application.kind === "desktop-application" ? qsTr("No open windows\nUse Launch beside the application name to get started.") : qsTr("Window is no longer available")
        font.pixelSize: Ui.Theme.fontSizeBody
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

    ApplicationDesktopActions {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    Ui.ThemeText {
        objectName: "applicationNoActions"
        visible: page.application.kind === "desktop-application" && (page.application.desktop_actions || []).length === 0
        width: parent.width
        text: qsTr("No additional actions provided by this application.")
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
    }

    Ui.ThemeText {
        visible: page.application.kind !== "desktop-shortcut" && (page.application.instances || []).length > 0
        width: parent.width
        text: qsTr("CPU, memory and history are available in Resources.")
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
}
