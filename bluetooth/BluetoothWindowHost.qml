import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: host

    required property Component content
    required property real surfaceWindowWidth

    property bool popoverVisible: false
    signal uiActivated(string workspaceId)
    signal uiDeactivated
    signal focusSearchRequested

    readonly property int windowHeight: 650

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor;
        return monitor ? (Quickshell.screens.find(function (screen) { return screen.name === monitor.name; }) || null) : null;
    }
    function workspaceId() { return Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id) : ""; }
    function screenWidth() { return anchor.screen && anchor.screen.width > 0 ? anchor.screen.width : 1280; }
    function screenHeight() { return anchor.screen && anchor.screen.height > 0 ? anchor.screen.height : 960; }
    function show() { popoverVisible = true; uiActivated(workspaceId()); focusSearchRequested(); }
    function hide() { popoverVisible = false; uiDeactivated(); }
    function toggle() { popoverVisible ? hide() : show(); }
    function closeRequested() { hide(); }

    IpcHandler {
        target: "bluetooth"
        readonly property bool visible: host.popoverVisible
        function ping(): string { return "pong"; }
        function status(): string { return host.popoverVisible ? "visible" : "hidden"; }
        function open(): void { host.show(); }
        function hide(): void { host.hide(); }
        function toggle(): void { host.toggle(); }
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: anchor
        screen: host.focusedScreen()
        visible: host.popoverVisible
        implicitWidth: host.surfaceWindowWidth
        implicitHeight: host.windowHeight
        color: "transparent"
        mask: Region { item: surface }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "shelllist-bluetooth"
        anchors { top: true; left: true }
        margins { // qmllint disable unresolved-type unqualified
            top: Math.round((host.screenHeight() - host.windowHeight) / 2)
            left: Math.round((host.screenWidth() - host.surfaceWindowWidth) / 2)
        }
        onVisibleChanged: if (visible) host.focusSearchRequested()

        Ui.VisualSurface {
            id: surface
            surfaceWidth: host.surfaceWindowWidth
            contentWidth: host.surfaceWindowWidth
            loadWhen: host.popoverVisible
            content: host.content
        }
    }

    HyprlandFocusGrab {
        active: host.popoverVisible
        windows: [anchor]
        onCleared: host.hide()
    }
}
