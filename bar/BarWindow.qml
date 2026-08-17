import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property var targetScreen
    required property BarController controller
    readonly property int barHeight: 51
    screen: targetScreen
    implicitHeight: barHeight
    color: "transparent"
    aboveWindows: true
    exclusiveZone: barHeight
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.namespace: "shelllist-bar"
    WlrLayershell.layer: WlrLayer.Top
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
