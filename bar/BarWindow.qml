import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Io as Io

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property ShellScreen targetScreen
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

    mask: Region { item: bar.visualSurface }
    function syncStyle(): void {
        if (Ui.Theme.hyprland && Hyprland.usingLua)
            styleClient.applyStyle("shelllist-bar", Ui.Theme.noAnimations, Ui.Theme.blurEnabled);
    }
    Io.HyprlandLayerRuleClient { id: styleClient }
    Component.onCompleted: syncStyle()
    Connections {
        target: Ui.Theme.hyprland ? Hyprland : null
        function onUsingLuaChanged(): void { window.syncStyle(); }
        function onRawEvent(event): void { if (event.name === "configreloaded") window.syncStyle(); }
    }
    Connections {
        target: Ui.Theme
        function onNoAnimationsChanged(): void { window.syncStyle(); }
    }
    BarContent {
        id: bar
        anchors.fill: parent
        controller: window.controller
        screenName: window.screen ? window.screen.name : ""
    }
}
