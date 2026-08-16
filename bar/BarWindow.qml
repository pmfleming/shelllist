import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property var targetScreen
    required property BarController controller
    screen: targetScreen
    implicitHeight: 51
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 51
    WlrLayershell.namespace: "shelllist-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
        right: true
    }

    BarContent {
        anchors.fill: parent
        controller: window.controller
        screenName: window.screen ? window.screen.name : ""
    }
}
