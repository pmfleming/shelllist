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

    Ui.ThemeText {
        objectName: "applicationHistoryStatus"
        visible: page.controller.historyInFlight
        width: parent.width
        text: qsTr("Loading period measurements…")
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
}
