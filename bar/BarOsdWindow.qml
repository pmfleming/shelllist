import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property var targetScreen
    required property BarController controller
    readonly property string focusedScreenName: controller.workspaces
        ? (controller.workspaces.focused_monitor || "") : ""
    readonly property bool targetIsFocused: focusedScreenName.length > 0
        ? (!!screen && screen.name === focusedScreenName)
        : (Quickshell.screens.length > 0 && screen === Quickshell.screens[0])

    screen: targetScreen
    // Keep the focused monitor's layer surface mapped so a media-key press does
    // not pay a Wayland surface creation/configure round trip before appearing.
    visible: targetIsFocused
    implicitWidth: 376
    implicitHeight: 104
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shelllist-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        bottom: true
        left: true
    }
    margins { // qmllint disable unresolved-type unqualified
        bottom: 86
        left: Math.max(0, Math.round(((window.screen ? window.screen.width : 376)
            - window.implicitWidth) / 2))
    }

    BarOsdContent {
        anchors.fill: parent
        controller: window.controller
    }
}
