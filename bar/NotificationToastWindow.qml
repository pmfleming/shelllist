pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

BarOverlayWindow {
    id: window

    readonly property var toasts: controller.visibleToasts()
    implicitWidth: 414
    implicitHeight: 640
    mask: Region { item: toastColumn }
    WlrLayershell.namespace: "shelllist-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        right: true
    }
    margins { // qmllint disable unresolved-type unqualified
        top: 67
        right: 16
    }

    Column {
        id: toastColumn
        width: 390
        anchors.right: parent.right
        spacing: Ui.Theme.spacingSm

        Repeater {
            model: window.toasts
            NotificationToastCard {
                required property var modelData
                notification: modelData
                controller: window.controller
                width: toastColumn.width
            }
        }
    }
}
