pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

BarOverlayWindow {
    id: window

    readonly property string targetScreenName: targetScreen ? targetScreen.name : ""
    readonly property var toastGroups: controller.visibleToastGroups(targetScreenName)
    focusedScreenOnly: false
    visible: toastGroups.length > 0
    implicitWidth: 414
    implicitHeight: Math.min(640, targetScreen ? targetScreen.height - 100 : 640)
    mask: Region {
        item: viewport
    }
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

    HoverHandler {
        id: reading
        parent: viewport
        onHoveredChanged: window.controller.setNotificationReading(window.targetScreenName, hovered)
    }
    Timer {
        interval: 1000
        repeat: true
        running: reading.hovered && window.visible
        onTriggered: window.controller.setNotificationReading(window.targetScreenName, true)
    }
    onVisibleChanged: if (!visible) controller.setNotificationReading(targetScreenName, false)
    Component.onDestruction: controller.setNotificationReading(targetScreenName, false)

    Flickable {
        id: viewport
        width: 390
        height: Math.min(window.height, toastColumn.implicitHeight)
        anchors.right: parent.right
        contentWidth: width
        contentHeight: toastColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: toastColumn
            width: viewport.width
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: Core.SerializedListModel {
                    rows: window.toastGroups.map(deck => ({key: deck.key, payload: deck}))
                }
                NotificationToastStack {
                    required property var resultData
                    group: JSON.parse(resultData.payload)
                    controller: window.controller
                    width: toastColumn.width
                    maximumHeight: viewport.height > 0 ? window.height : 480
                }
            }
        }
    }
}
