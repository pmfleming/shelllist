import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application
    required property real uiScale

    Text {
        visible: page.application.running
        width: parent.width
        text: "Total usage · " + Presentation.usageText(page.application)
        color: Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        visible: page.application.running && Number(page.application.disk_space_total_bytes || 0) > 0
        width: parent.width
        text: "Application data · " + Presentation.memoryText(page.application.disk_space_total_bytes)
            + " total · " + Presentation.memoryText(page.application.disk_space_permanent_bytes)
            + " permanent · " + Presentation.memoryText(page.application.disk_space_temporary_bytes)
            + " temporary"
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    ApplicationResourceHistory {
        visible: page.application.running
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    Ui.CenteredMessage {
        visible: !page.application.running
        width: parent.width
        height: 120
        text: "Resources are available while the application is running"
        font.pixelSize: Ui.Theme.fontSizeBody
    }
}
