import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property var targetScreen
    required property BarController controller
    readonly property string focusedScreenName: controller.workspaces
        ? (controller.workspaces.focused_monitor || "") : ""
    readonly property bool targetIsFocused: focusedScreenName.length > 0
        ? (!!screen && screen.name === focusedScreenName)
        : (Quickshell.screens.length > 0 && screen === Quickshell.screens[0])
    readonly property var toasts: controller.visibleToasts()

    screen: targetScreen
    visible: targetIsFocused
    implicitWidth: 414
    implicitHeight: 640
    color: "transparent"
    mask: Region { item: toastColumn }
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
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
