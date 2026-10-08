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

    // Keep the shared page/navigation contract, but give the resource grid the
    // viewport rather than a content-sized history stack. Restored scroll offsets
    // are clamped to zero by DetailFlickable as the page resizes.
    ApplicationResourceHistory {
        width: parent.width
        height: page.height
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
    }
}
