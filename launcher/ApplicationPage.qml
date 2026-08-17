import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application
    required property real uiScale
    required property int actionHeight

    Text {
        visible: page.application.comment && page.application.comment.length > 0
        width: parent.width
        text: page.application.comment || ""
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
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
        visible: (page.application.instances || []).length === 0
            && (page.application.desktop_actions || []).length === 0
        width: parent.width
        height: 120
        text: page.application.kind === "desktop-shortcut"
            ? "This shortcut opens content in another application"
            : page.application.kind === "desktop-application"
                ? "No additional actions"
                : "Window is no longer available"
        font.pixelSize: Ui.Theme.fontSizeBody
    }
}
