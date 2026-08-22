import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var historyPoints: controller.resourceHistory || []
    readonly property var latestHistoryPoint: historyPoints.length > 0
        ? historyPoints[historyPoints.length - 1] : null
    readonly property var detailResource: application.running ? application : latestHistoryPoint || ({})

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

    ApplicationResourceDetails {
        visible: page.application.running || page.latestHistoryPoint !== null
        width: parent.width
        resource: page.detailResource
        historical: !page.application.running
        uiScale: page.uiScale
    }
}
