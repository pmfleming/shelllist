import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

Item {
    id: host

    required property var controller
    required property Component content

    readonly property string launchMode: (Quickshell.env("SHELLLIST_WIFI_MODE") || "floating").toLowerCase()
    readonly property bool popoverMode: launchMode === "popover"
    readonly property bool floatingMode: !popoverMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible
    property bool popoverVisible: false
    property int floatingPlacementAttempts: 0
    readonly property bool noAnimations: Theme.noAnimations
    property int popoverNoAnimRuleState: -1
    property var pendingPopoverLayerRuleArgs: []
    readonly property var placementScreen: floatingMode
        ? (wifiWindow && wifiWindow.screen ? wifiWindow.screen : null)
        : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property int currentWindowHeight: Math.round(screenGeometry().height * 0.75)

    function screenGeometry() {
        const screen = placementScreen;
        return {
            x: screen ? screen.x || 0 : 0,
            y: screen ? screen.y || 0 : 0,
            width: screen && screen.width > 0 ? screen.width : 1280,
            height: screen && screen.height > 0 ? screen.height : 960
        };
    }

    function targetLayerMarginX() { return Math.round((screenGeometry().width - controller.surfaceWindowWidth) / 2); }
    function targetLayerMarginY() { return Math.round((screenGeometry().height - currentWindowHeight) / 2); }
    function targetWindowX() { return screenGeometry().x + targetLayerMarginX(); }
    function targetWindowY() { return screenGeometry().y + targetLayerMarginY(); }

    // In popover mode placement is pure bindings on the PanelWindow margins;
    // only the floating window needs Hyprland dispatch nudges.
    function requestWindowPlacement() {
        if (!floatingMode || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return;
        floatingPlacementAttempts = 0;
        floatingPlacementTimer.restart();
    }

    function syncPopoverAnimationRule() {
        const desiredState = noAnimations ? 1 : 0;
        if (!popoverMode || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || popoverNoAnimRuleState === desiredState)
            return;
        if (Theme.noAnimationsOverride === null && Theme.hyprland && !Theme.hyprAnimationsKnown)
            return;
        applyPopoverLayerAnimationRule(noAnimations ? "animation 0 shelllist-wifi" : "animation unset shelllist-wifi");
        popoverNoAnimRuleState = desiredState;
    }

    function applyPopoverLayerAnimationRule(rule) {
        const args = ["hyprctl", "keyword", "layerrule", rule];
        if (popoverLayerRuleProc.running) {
            pendingPopoverLayerRuleArgs = args;
            return;
        }
        popoverLayerRuleProc.exec(args);
    }

    function applyCompositorWindowRules() {
        if (!floatingMode || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
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
        Theme.refreshHyprAnimations();
        syncPopoverAnimationRule();
        popoverVisible = true;
        controller.refresh();
        Qt.callLater(controller.focusSearchBox);
    }

    function hidePopover() {
        if (popoverMode)
            popoverVisible = false;
    }

    function togglePopover() { popoverVisible ? hidePopover() : showPopover(); }

    Timer {
        id: floatingPlacementTimer
        interval: 16
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            host.floatingPlacementAttempts += 1;
            if (host.floatingPlacementAttempts === 1)
                host.applyCompositorWindowRules();
            Hyprland.dispatch("focuswindow title:Shelllist Wi-Fi");
            Hyprland.dispatch("setfloating");
            Hyprland.dispatch("movewindowpixel exact " + host.targetWindowX() + " " + host.targetWindowY() + ",title:Shelllist Wi-Fi");
            if (host.floatingPlacementAttempts >= 24)
                stop();
        }
    }

    onNoAnimationsChanged: syncPopoverAnimationRule()

    Process {
        id: popoverLayerRuleProc
        onRunningChanged: if (!running && host.pendingPopoverLayerRuleArgs.length > 0) {
            const args = host.pendingPopoverLayerRuleArgs;
            host.pendingPopoverLayerRuleArgs = [];
            popoverLayerRuleProc.exec(args);
        }
    }

    IpcHandler {
        enabled: host.popoverMode
        target: "wifi"
        readonly property bool visible: host.popoverVisible
        function ping(): string { return "pong"; }
        function open(): void { host.showPopover(); }
        function hide(): void { host.hidePopover(); }
        function toggle(): void { host.togglePopover(); }
    }

    // Quickshell's generated type info marks PanelWindow as an interface and
    // does not give the linter enough information for its margins group.
    PanelWindow { // qmllint disable uncreatable-type
        id: popoverAnchor
        visible: host.popoverWindowVisible
        implicitWidth: host.controller.surfaceWindowWidth
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
        onVisibleChanged: if (visible) Qt.callLater(host.controller.focusSearchBox)

        VisualSurface {
            id: popoverVisualSurface
            controller: host.controller
            loadWhen: host.popoverWindowVisible
            content: host.content
        }
    }

    FloatingWindow {
        id: wifiWindow
        visible: host.floatingMode
        implicitWidth: host.controller.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        title: "Shelllist Wi-Fi"
        color: "transparent"
        mask: Region { item: floatingVisualSurface }
        onWindowConnected: host.requestWindowPlacement()
        onVisibleChanged: if (visible) Qt.callLater(host.requestWindowPlacement)

        VisualSurface {
            id: floatingVisualSurface
            controller: host.controller
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
