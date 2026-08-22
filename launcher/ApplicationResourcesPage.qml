import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var historyPoints: controller.resourceHistory || []
    readonly property var latestHistoryPoint: historyPoints.length > 0
        ? historyPoints[historyPoints.length - 1] : null

    ApplicationResourceMetadata {
        visible: page.application.running || page.latestHistoryPoint !== null
        width: parent.width
        application: page.application
        latestPoint: page.latestHistoryPoint
        uiScale: page.uiScale
    }

    Text {
        visible: !page.application.running
            && (page.controller.historyInFlight || page.controller.resourceHistory.length > 0)
        width: parent.width
        text: "Application is not running · showing retained measurements"
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    ApplicationResourceHistory {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }
}
