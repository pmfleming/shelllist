import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."
import "process"
import Shelllist.Ui

Item {
    id: host

    required property Component content
    required property real surfaceWindowWidth
    required property real currentWindowWidth

    signal uiActivated(string workspaceId)
    signal uiDeactivated
    signal focusSearchRequested

    readonly property string launchMode: (Quickshell.env("SHELLLIST_WIFI_MODE") || "popover").toLowerCase()
    readonly property bool popoverMode: launchMode === "popover"
    readonly property bool floatingMode: !popoverMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible
    readonly property bool uiActive: floatingMode || popoverWindowVisible
    property bool popoverVisible: false
    readonly property bool noAnimations: Theme.noAnimations
    property int popoverNoAnimRuleState: -1
    property string pendingPopoverLayerRule: ""
    readonly property var placementScreen: floatingMode
        ? (wifiWindow && wifiWindow.screen ? wifiWindow.screen : null)
        : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property int currentWindowHeight: Math.round(screenGeometry().height * 0.75)

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor;
        if (!monitor)
            return null;
        return Quickshell.screens.find(function (screen) { return screen.name === monitor.name; }) || null;
    }

    function shelllistWorkspaceId() {
        if (!Theme.hyprland || !Hyprland.focusedWorkspace)
            return "";
        return String(Hyprland.focusedWorkspace.id);
    }

    function screenValue(key, fallback) { const screen = placementScreen; return screen ? (screen[key] || fallback) : fallback; }
    function screenDimension(key, fallback) { const value = screenValue(key, fallback); return value > 0 ? value : fallback; }
    function screenGeometry() { return { x: screenValue("x", 0), y: screenValue("y", 0), width: screenDimension("width", 1280), height: screenDimension("height", 960) }; }

    function targetLayerMarginX() { return Math.round((screenGeometry().width - surfaceWindowWidth) / 2); }
    function targetLayerMarginY() { return Math.round((screenGeometry().height - currentWindowHeight) / 2); }
    function targetWindowX() { return screenGeometry().x + targetLayerMarginX(); }
    function targetWindowY() { return screenGeometry().y + targetLayerMarginY(); }

    // In popover mode placement is pure bindings on the PanelWindow margins;
    // only the floating window needs Hyprland dispatch nudges.
    function requestWindowPlacement() {
        if (!floatingMode || !Theme.hyprland)
            return;
        floatingPlacementTimer.restart();
    }

    function popoverAnimationRuleReady(desiredState) {
        return popoverMode
            && Theme.hyprland
            && popoverNoAnimRuleState !== desiredState;
    }
    function syncPopoverAnimationRule() {
        const desiredState = noAnimations ? 1 : 0;
        if (!popoverAnimationRuleReady(desiredState))
            return;
        applyPopoverLayerAnimationRule(noAnimations ? "animation 0 shelllist-wifi" : "animation unset shelllist-wifi");
        popoverNoAnimRuleState = desiredState;
    }

    function applyPopoverLayerAnimationRule(rule) {
        if (popoverLayerRuleProc.running) {
            pendingPopoverLayerRule = rule;
            return;
        }
        popoverLayerRuleProc.exec(["hyprctl", "keyword", "layerrule", rule]);
    }

    function runPendingPopoverLayerRule() {
        if (pendingPopoverLayerRule.length === 0)
            return;
        const rule = pendingPopoverLayerRule;
        pendingPopoverLayerRule = "";
        applyPopoverLayerAnimationRule(rule);
    }

    function applyCompositorWindowRules() {
        if (!floatingMode || !Theme.hyprland)
            return;
        Hyprland.dispatch("setprop title:Shelllist.* noanim " + (noAnimations ? "1" : "0"));
        Hyprland.dispatch("setprop title:Shelllist.* noborder 1");
        Hyprland.dispatch("setprop title:Shelllist.* noshadow 1");
    }

    function closeRequested() {
        if (popoverMode) {
            hidePopover();
            return;
        }
        Qt.quit();
    }

    function showPopover() {
        if (!popoverMode)
            return;
        syncPopoverAnimationRule();
        popoverVisible = true;
        uiActivated(shelllistWorkspaceId());
        focusSearchRequested();
    }

    function hidePopover() {
        if (!popoverMode)
            return;
        popoverVisible = false;
        uiDeactivated();
    }

    function togglePopover() { popoverVisible ? hidePopover() : showPopover(); }

    Timer {
        id: floatingPlacementTimer
        interval: 30
        repeat: false
        onTriggered: {
            host.applyCompositorWindowRules();
            Hyprland.dispatch("focuswindow title:Shelllist Wi-Fi");
            Hyprland.dispatch("setfloating");
            Hyprland.dispatch("movewindowpixel exact " + host.targetWindowX() + " " + host.targetWindowY() + ",title:Shelllist Wi-Fi");
        }
    }

    onNoAnimationsChanged: syncPopoverAnimationRule()

    CommandProcess {
        id: popoverLayerRuleProc
        onFinished: function () { host.runPendingPopoverLayerRule(); }
    }

    IpcHandler {
        enabled: host.popoverMode
        target: "wifi"
        readonly property bool visible: host.popoverVisible
        function ping(): string { return "pong"; }
        function status(): string { return host.popoverVisible ? "visible" : "hidden"; }
        function open(): void { host.showPopover(); }
        function hide(): void { host.hidePopover(); }
        function toggle(): void { host.togglePopover(); }
    }

    WifiGlobalShortcut {
        onTriggered: host.togglePopover()
    }

    // Quickshell's generated type info marks PanelWindow as an interface and
    // does not give the linter enough information for its margins group.
    PanelWindow { // qmllint disable uncreatable-type
        id: popoverAnchor
        screen: host.focusedScreen()
        visible: host.popoverWindowVisible
        implicitWidth: host.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        color: "transparent"
        mask: Region { item: popoverVisualSurface }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "shelllist-wifi"
        anchors {
            top: true
            left: true
        }
        margins { // qmllint disable unresolved-type unqualified
            top: host.targetLayerMarginY()
            left: host.targetLayerMarginX()
        }
        onVisibleChanged: if (visible) host.focusSearchRequested()

        VisualSurface {
            id: popoverVisualSurface
            surfaceWidth: host.surfaceWindowWidth
            contentWidth: host.currentWindowWidth
            loadWhen: host.popoverWindowVisible
            content: host.content
        }
    }

    FloatingWindow {
        id: wifiWindow
        visible: host.floatingMode
        implicitWidth: host.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        title: "Shelllist Wi-Fi"
        color: "transparent"
        mask: Region { item: floatingVisualSurface }
        onWindowConnected: host.requestWindowPlacement()
        onVisibleChanged: if (visible) Qt.callLater(host.requestWindowPlacement)

        VisualSurface {
            id: floatingVisualSurface
            surfaceWidth: host.surfaceWindowWidth
            contentWidth: host.currentWindowWidth
            loadWhen: host.floatingMode
            content: host.content
        }
    }

    HyprlandFocusGrab {
        active: host.popoverMode && host.popoverVisible
        windows: [popoverAnchor]
        onCleared: host.hidePopover()
    }
}
