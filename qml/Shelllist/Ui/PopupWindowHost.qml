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
    required property real surfaceWindowWidth
    required property real currentWindowWidth
    required property string modeEnvironment
    required property string ipcTarget
    required property string shortcutName
    required property string shortcutDescription
    required property string windowTitle
    required property string layerNamespace

    property real windowHeightRatio: Theme.popupHeightRatio
    property int windowTopInset: 0
    property int windowBottomInset: 0
    property bool fitToWorkspace: false
    property string contentAlignment: "center"
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
    property int popoverNoAnimRuleState: -1

    readonly property string launchMode: (Quickshell.env(modeEnvironment) || defaultLaunchMode).toLowerCase()
    readonly property bool popoverMode: launchMode === "popover"
    readonly property bool floatingMode: !popoverMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible && (!workspaceClient.active || workspaceClient.ready)
    readonly property bool uiActive: floatingMode || (popoverMode && popoverVisible)
    readonly property bool noAnimations: Theme.noAnimations
    readonly property var placementScreen: floatingMode ? (floatingWindow && floatingWindow.screen ? floatingWindow.screen : null) : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property var workspaceArea: fitToWorkspace && Theme.hyprland ? WorkArea.rectangle(screenGeometry(), workspaceClient.insets) : null
    readonly property real availableWindowWidth: workspaceArea ? workspaceArea.width : screenGeometry().width
    readonly property real renderSurfaceWidth: workspaceArea ? Math.min(surfaceWindowWidth, workspaceArea.width) : surfaceWindowWidth
    readonly property real renderContentWidth: Math.min(currentWindowWidth, renderSurfaceWidth)
    readonly property bool workspaceRightAnchored: workspaceArea !== null && contentAlignment === "right"
    readonly property int currentWindowHeight: workspaceArea ? workspaceArea.height : windowTopInset > 0 || windowBottomInset > 0 ? Math.max(1, Math.round(screenGeometry().height - windowTopInset - windowBottomInset)) : Math.round(screenGeometry().height * windowHeightRatio)
    readonly property real placementX: targetWindowX()
    readonly property real placementY: targetWindowY()

    signal uiActivated(string workspaceId)
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
        if (workspaceArea) {
            if (contentAlignment === "right")
                return screenGeometry().width - workspaceArea.right - renderSurfaceWidth;
            if (contentAlignment === "left")
                return workspaceArea.left;
            return workspaceArea.left + Math.round((workspaceArea.width - renderSurfaceWidth) / 2);
        }
        if (contentAlignment === "right")
            return Math.max(Theme.contentMargin, Math.round(screenGeometry().width - renderSurfaceWidth - Theme.contentMargin));
        if (contentAlignment === "left")
            return Theme.contentMargin;
        return Math.round((screenGeometry().width - renderSurfaceWidth) / 2);
    }
    function targetLayerMarginY() {
        if (workspaceArea)
            return workspaceArea.top;
        return windowTopInset > 0 || windowBottomInset > 0 ? windowTopInset : Math.round((screenGeometry().height - currentWindowHeight) / 2);
    }
    function targetWindowX() {
        return screenGeometry().x + targetLayerMarginX();
    }
    function targetWindowY() {
        return screenGeometry().y + targetLayerMarginY();
    }
    function contentOffsetX() {
        if (contentAlignment === "right")
            return Math.round(renderSurfaceWidth - renderContentWidth);
        if (contentAlignment === "left")
            return 0;
        return Math.round((renderSurfaceWidth - renderContentWidth) / 2);
    }
    function targetContentWindowX() {
        return targetWindowX() + contentOffsetX();
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

    function popoverAnimationRuleReady(desiredState) {
        return popoverMode && Theme.hyprland && popoverNoAnimRuleState !== desiredState;
    }
    function syncPopoverAnimationRule() {
        const desiredState = noAnimations ? 1 : 0;
        if (!popoverAnimationRuleReady(desiredState))
            return;
        layerRuleClient.apply(noAnimations ? "animation 0 " + layerNamespace : "animation unset " + layerNamespace);
        popoverNoAnimRuleState = desiredState;
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
        active: host.fitToWorkspace && Theme.hyprland && host.uiActive
        monitorName: host.screenValue("name", "")
    }
    Connections {
        target: host.placementScreen
        ignoreUnknownSignals: true
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
            bottom: host.workspaceArea !== null
            right: host.workspaceRightAnchored
            left: !host.workspaceRightAnchored
        }
        margins { // qmllint disable unresolved-type unqualified
            top: host.targetLayerMarginY()
            bottom: host.workspaceArea ? host.workspaceArea.bottom : 0
            right: host.workspaceRightAnchored ? host.workspaceArea.right : 0
            left: host.workspaceRightAnchored ? 0 : host.targetLayerMarginX()
        }
        onVisibleChanged: if (visible)
            host.focusSearchRequested()

        VisualSurface {
            id: popoverVisualSurface
            surfaceWidth: host.renderSurfaceWidth
            contentWidth: host.renderContentWidth
            loadWhen: host.popoverWindowVisible
            retainLoaded: host.retainContentLoaded
            horizontalAlignment: host.contentAlignment
            content: host.content
        }
    }

    Connections {
        // ProxyWindowBase exposes its QQuickWindow only through this framework
        // property; the backing window owns the actual frameSwapped signal.
        // qmllint disable missing-property
        target: popoverAnchor["_backingWindow"]
        // qmllint enable missing-property
        ignoreUnknownSignals: true
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
            surfaceWidth: host.renderSurfaceWidth
            contentWidth: host.renderContentWidth
            loadWhen: host.floatingMode
            retainLoaded: host.retainContentLoaded
            horizontalAlignment: host.contentAlignment
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
