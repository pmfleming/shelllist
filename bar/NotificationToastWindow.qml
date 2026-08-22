pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

BarOverlayWindow {
    id: window

    readonly property string targetScreenName: targetScreen ? targetScreen.name : ""
    readonly property var toastGroups: controller.visibleToastGroups(targetScreenName)
    focusedScreenOnly: false
    visible: toastGroups.length > 0
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
            model: window.toastGroups
            NotificationToastStack {
                required property var modelData
                group: modelData
                controller: window.controller
                width: toastColumn.width
            }
        }
    }
}
