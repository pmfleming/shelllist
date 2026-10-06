import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    objectName: "applicationPage"
    viewMemory: controller.viewMemory
    memoryTab: "application"

    required property ApplicationController controller
    required property var application
    required property real uiScale
    required property int actionHeight

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

    ApplicationInstanceList {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
        actionHeight: page.actionHeight
    }

    ApplicationDesktopActions {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    Ui.CenteredMessage {
        objectName: "applicationEmptyState"
        visible: (page.application.instances || []).length === 0
        width: parent.width
        height: Math.max(120, implicitHeight)
        text: page.application.kind === "desktop-shortcut" ? "This shortcut opens content in another application" : page.application.kind === "desktop-application" ? "No open windows · Launch to open this application" : "Window is no longer available"
        font.pixelSize: Ui.Theme.fontSizeBody
    }
}
