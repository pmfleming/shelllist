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

    // Fill the viewport normally; at short heights keep passive readings at
    // their readable minimum and use the shared page scrolling/navigation.
    ApplicationResourceHistory {
        width: parent.width
        height: Math.max(page.height, implicitHeight)
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }
}
