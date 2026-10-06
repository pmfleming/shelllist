import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    objectName: "applicationResourcesPage"
    viewMemory: controller.viewMemory
    memoryTab: "resources"

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var historyPoints: controller.resourceHistory || []
    readonly property var latestHistoryPoint: historyPoints.length > 0 ? historyPoints[historyPoints.length - 1] : null

    Ui.ThemeText {
        objectName: "applicationHistoryStatus"
        visible: page.controller.historyInFlight
        width: parent.width
        text: qsTr("Loading period measurements… Latest snapshot values remain separate from history.")
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    ApplicationResourceHistory {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }

    ApplicationResourceMetadata {
        visible: page.application.running || page.latestHistoryPoint !== null
        width: parent.width
        application: page.application
        latestPoint: page.latestHistoryPoint
        uiScale: page.uiScale
    }
}
