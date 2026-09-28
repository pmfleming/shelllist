pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Shelllist.Io as Io
import Quickshell.Wayland
import QtQuick
import "HyprlandDispatch.js" as HyprlandDispatch
import "../Io/HyprlandWorkArea.js" as WorkArea

Item {
    id: host

    required property Component content
    required property PopoverGeometry geometry
    required property real currentWindowWidth
    required property string modeEnvironment
    required property string ipcTarget
    required property string shortcutName
    required property string shortcutDescription
    required property string windowTitle
    required property string layerNamespace

    property string defaultLaunchMode: "popover"
    property bool popoverVisible: false
    property double openRequestedAtMs: 0
    property double firstFrameAtMs: 0
    property double lastOpenToFirstFrameMs: -1
    property bool firstFramePending: false
    property bool retainOnFocusLoss: false
    property bool retainContentLoaded: false
    property bool ipcEnabled: true
    property bool shortcutEnabled: true

    readonly property string launchMode: (Quickshell.env(modeEnvironment) || defaultLaunchMode).toLowerCase()
    readonly property bool popoverMode: launchMode === "popover"
    readonly property bool floatingMode: !popoverMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible
    readonly property bool uiActive: floatingMode || (popoverMode && popoverVisible)
    readonly property bool noAnimations: Theme.noAnimations
    readonly property ShellScreen placementScreen: floatingMode ? (floatingWindow && floatingWindow.screen ? floatingWindow.screen : null) : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property var workspaceArea: WorkArea.rectangle(screenGeometry(), Theme.hyprland ? workspaceClient.insets : null)
    readonly property real availableWindowWidth: workspaceArea.width
    readonly property real availableWindowHeight: workspaceArea.height
    readonly property real renderSurfaceWidth: geometry.surfaceWidth
    readonly property real renderContentWidth: Math.min(currentWindowWidth, renderSurfaceWidth)
    readonly property int currentWindowHeight: geometry.height
    readonly property real placementX: targetWindowX()
    readonly property real placementY: targetWindowY()

    signal uiActivated(string workspaceId)
    signal uiDeactivating
    signal uiDeactivated
    signal focusSearchRequested

    function focusedScreen() {
        if (Theme.hyprland) {
            const monitor = Hyprland.focusedMonitor;
            if (monitor) {
                const matched = Quickshell.screens.find(function (screen) {
                    return screen.name === monitor.name;
                });
                if (matched)
                    return matched;
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function shelllistWorkspaceId() {
        if (!Theme.hyprland || !Hyprland.focusedWorkspace)
            return "";
        return String(Hyprland.focusedWorkspace.id);
    }

    function screenValue(key, fallback) {
        const screen = placementScreen || focusedScreen();
        const value = screen ? screen[key] : undefined;
        return value === undefined || value === null ? fallback : value;
    }
    function screenDimension(key, fallback) {
        const value = screenValue(key, fallback);
        return value > 0 ? value : fallback;
    }
    function screenGeometry() {
        return {
            x: screenValue("x", 0),
            y: screenValue("y", 0),
            width: screenDimension("width", 1280),
            height: screenDimension("height", 960)
        };
    }

    function targetLayerMarginX() {
        return workspaceArea.left + geometry.x;
    }
    function targetLayerMarginY() {
        return workspaceArea.top + geometry.y;
    }
    function targetWindowX() {
        return screenGeometry().x + targetLayerMarginX();
    }
    function targetWindowY() {
        return screenGeometry().y + targetLayerMarginY();
    }

    function requestWindowPlacement() {
        if (!floatingMode || !Theme.hyprland)
            return;
        floatingPlacementTimer.restart();
    }

    function setWindowProperty(selector, legacyName, legacyValue, luaName, luaValue) {
        Hyprland.dispatch(HyprlandDispatch.windowProperty(Hyprland.usingLua, selector, legacyName, legacyValue, luaName, luaValue));
    }
    function focusWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.focusWindow(Hyprland.usingLua, selector));
    }
    function floatWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.floatWindow(Hyprland.usingLua, selector));
    }
    function moveWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.moveWindow(Hyprland.usingLua, selector, targetWindowX(), targetWindowY()));
    }

    function syncPopoverAnimationRule() {
        if (!popoverMode || !Theme.hyprland)
            return;
        // Named Lua rules update idempotently, including after config reload.
        if (Hyprland.usingLua)
            layerRuleClient.applyStyle(layerNamespace, noAnimations, Theme.blurEnabled);
        else
            layerRuleClient.apply(noAnimations ? "animation 0 " + layerNamespace : "animation unset " + layerNamespace);
    }
    function applyCompositorWindowRules() {
        if (!floatingMode || !Theme.hyprland)
            return;
        const selector = "title:" + windowTitle;
        const animationValue = noAnimations ? "1" : "0";
        setWindowProperty(selector, "noanim", animationValue, "no_anim", animationValue);
        setWindowProperty(selector, "noborder", "1", "decorate", "0");
        setWindowProperty(selector, "noshadow", "1", "no_shadow", "1");
    }

    function closeRequested() {
        if (popoverMode) {
            hidePopover();
            return;
        }
        uiDeactivated();
        Qt.quit();
    }

    function showPopover() {
        if (!popoverMode)
            return;
        syncPopoverAnimationRule();
        openRequestedAtMs = Date.now();
        firstFrameAtMs = 0;
        lastOpenToFirstFrameMs = -1;
        firstFramePending = true;
        popoverVisible = true;
        uiActivated(shelllistWorkspaceId());
        focusSearchRequested();
    }
    function recordFirstFrame(): void {
        if (!firstFramePending)
            return;
        firstFramePending = false;
        firstFrameAtMs = Date.now();
        lastOpenToFirstFrameMs = Math.max(0, firstFrameAtMs - openRequestedAtMs);
    }
    function hidePopover() {
        if (!popoverMode)
            return;
        // Snapshot before hide; keep domain cleanup after native focus loss.
        uiDeactivating();
        popoverVisible = false;
        uiDeactivated();
    }
    function togglePopover() {
        popoverVisible ? hidePopover() : showPopover();
    }
    function show() {
        showPopover();
    }
    function hide() {
        hidePopover();
    }
    function toggle() {
        togglePopover();
    }

    Timer {
        id: floatingPlacementTimer
        interval: 30
        repeat: false
        onTriggered: {
            host.applyCompositorWindowRules();
            const selector = "title:" + host.windowTitle;
            host.focusWindow(selector);
            host.floatWindow(selector);
            host.moveWindow(selector);
        }
    }

    // Geometry updates should move a floating preview without stealing focus.
    onPlacementXChanged: if (floatingMode)
        floatingMoveTimer.restart()
    onPlacementYChanged: if (floatingMode)
        floatingMoveTimer.restart()
    Timer {
        id: floatingMoveTimer
        interval: 0
        onTriggered: if (host.floatingMode && Theme.hyprland)
            host.moveWindow("title:" + host.windowTitle)
    }

    onNoAnimationsChanged: syncPopoverAnimationRule()
    Component.onCompleted: if (floatingMode)
        Qt.callLater(function () {
            host.uiActivated(host.shelllistWorkspaceId());
            host.focusSearchRequested();
        })

    Io.HyprlandLayerRuleClient {
        id: layerRuleClient
    }
    Io.HyprlandWorkAreaClient {
        id: workspaceClient
        active: Theme.hyprland && host.uiActive
        monitorName: host.screenValue("name", "")
    }
    Connections {
        target: host.placementScreen
        function onWidthChanged(): void {
            workspaceClient.scheduleRefresh();
        }
        function onHeightChanged(): void {
            workspaceClient.scheduleRefresh();
        }
        function onDevicePixelRatioChanged(): void {
            workspaceClient.scheduleRefresh();
        }
    }

    IpcHandler {
        enabled: host.popoverMode && host.ipcEnabled
        target: host.ipcTarget
        readonly property bool visible: host.popoverVisible
        function ping(): string {
            return "pong";
        }
        function status(): string {
            return host.popoverVisible ? "visible" : "hidden";
        }
        function open(): void {
            host.showPopover();
        }
        function hide(): void {
            host.hidePopover();
        }
        function toggle(): void {
            host.togglePopover();
        }
    }

    Loader {
        active: host.shortcutEnabled
        sourceComponent: Component {
            ShelllistGlobalShortcut {
                shortcutName: host.shortcutName
                description: host.shortcutDescription
                onTriggered: host.togglePopover()
            }
        }
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: popoverAnchor
        screen: host.focusedScreen()
        visible: host.popoverWindowVisible
        implicitWidth: host.renderSurfaceWidth
        implicitHeight: host.currentWindowHeight
        color: "transparent"
        mask: Region {
            item: popoverVisualSurface
        }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: host.layerNamespace
        // Let layer-shell anchor the outer edges; size changes must not move them.
        anchors {
            top: true
            left: true
        }
        margins { // qmllint disable unresolved-type unqualified
            top: host.targetLayerMarginY()
            left: host.targetLayerMarginX()
        }
        onVisibleChanged: if (visible)
            host.focusSearchRequested()

        VisualSurface {
            id: popoverVisualSurface
            contentWidth: host.renderContentWidth
            canvasWidth: host.currentWindowWidth
            minimumContentHeight: host.geometry.minimumContentHeight
            loadWhen: host.popoverWindowVisible
            retainLoaded: host.retainContentLoaded
            content: host.content
        }
    }

    Connections {
        // The visual item's public attached window owns frameSwapped.
        target: popoverVisualSurface.Window.window
        function onFrameSwapped(): void {
            host.recordFirstFrame();
        }
    }

    FloatingWindow {
        id: floatingWindow
        visible: host.floatingMode
        implicitWidth: host.renderSurfaceWidth
        implicitHeight: host.currentWindowHeight
        title: host.windowTitle
        color: "transparent"
        mask: Region {
            item: floatingVisualSurface
        }
        onWindowConnected: host.requestWindowPlacement()
        onVisibleChanged: if (visible) {
            Qt.callLater(host.requestWindowPlacement);
            Qt.callLater(host.focusSearchRequested);
        }

        VisualSurface {
            id: floatingVisualSurface
            contentWidth: host.renderContentWidth
            canvasWidth: host.currentWindowWidth
            minimumContentHeight: host.geometry.minimumContentHeight
            loadWhen: host.floatingMode
            retainLoaded: host.retainContentLoaded
            content: host.content
        }
    }

    HyprlandFocusGrab {
        active: Theme.hyprland && host.popoverWindowVisible
        windows: [popoverAnchor]
        onCleared: if (!host.retainOnFocusLoss)
            host.hidePopover()
    }
}
