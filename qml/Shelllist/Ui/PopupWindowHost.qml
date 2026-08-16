pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Shelllist.Io as Io
import Quickshell.Wayland
import QtQuick
import "HyprlandDispatch.js" as HyprlandDispatch

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
    property string defaultLaunchMode: "popover"
    property bool popoverVisible: false
    property bool retainOnFocusLoss: false
    property bool retainContentLoaded: false
    property bool ipcEnabled: true
    property bool shortcutEnabled: true
    property int popoverNoAnimRuleState: -1

    readonly property string launchMode: (Quickshell.env(modeEnvironment) || defaultLaunchMode).toLowerCase()
    readonly property bool popoverMode: launchMode === "popover"
    readonly property bool floatingMode: !popoverMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible
    readonly property bool uiActive: floatingMode || popoverWindowVisible
    readonly property bool noAnimations: Theme.noAnimations
    readonly property var placementScreen: floatingMode
        ? (floatingWindow && floatingWindow.screen ? floatingWindow.screen : null)
        : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property int currentWindowHeight: Math.round(screenGeometry().height * windowHeightRatio)

    signal uiActivated(string workspaceId)
    signal uiDeactivated
    signal focusSearchRequested

    function focusedScreen() {
        if (Theme.hyprland) {
            const monitor = Hyprland.focusedMonitor;
            if (monitor) {
                const matched = Quickshell.screens.find(function (screen) { return screen.name === monitor.name; });
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

    function targetLayerMarginX() { return Math.round((screenGeometry().width - surfaceWindowWidth) / 2); }
    function targetLayerMarginY() { return Math.round((screenGeometry().height - currentWindowHeight) / 2); }
    function targetWindowX() { return screenGeometry().x + targetLayerMarginX(); }
    function targetWindowY() { return screenGeometry().y + targetLayerMarginY(); }

    function requestWindowPlacement() {
        if (!floatingMode || !Theme.hyprland)
            return;
        floatingPlacementTimer.restart();
    }

    function setWindowProperty(selector, legacyName, legacyValue, luaName, luaValue) {
        Hyprland.dispatch(HyprlandDispatch.windowProperty(Hyprland.usingLua, selector,
            legacyName, legacyValue, luaName, luaValue));
    }
    function focusWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.focusWindow(Hyprland.usingLua, selector));
    }
    function floatWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.floatWindow(Hyprland.usingLua, selector));
    }
    function moveWindow(selector) {
        Hyprland.dispatch(HyprlandDispatch.moveWindow(Hyprland.usingLua, selector,
            targetWindowX(), targetWindowY()));
    }

    function popoverAnimationRuleReady(desiredState) {
        return popoverMode && Theme.hyprland && popoverNoAnimRuleState !== desiredState;
    }
    function syncPopoverAnimationRule() {
        const desiredState = noAnimations ? 1 : 0;
        if (!popoverAnimationRuleReady(desiredState))
            return;
        layerRuleClient.apply(noAnimations
            ? "animation 0 " + layerNamespace
            : "animation unset " + layerNamespace);
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
    function show() { showPopover(); }
    function hide() { hidePopover(); }
    function toggle() { togglePopover(); }

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

    onNoAnimationsChanged: syncPopoverAnimationRule()
    Component.onCompleted: if (floatingMode) Qt.callLater(function () {
        host.uiActivated(host.shelllistWorkspaceId());
        host.focusSearchRequested();
    })

    Io.HyprlandLayerRuleClient { id: layerRuleClient }

    IpcHandler {
        enabled: host.popoverMode && host.ipcEnabled
        target: host.ipcTarget
        readonly property bool visible: host.popoverVisible
        function ping(): string { return "pong"; }
        function status(): string { return host.popoverVisible ? "visible" : "hidden"; }
        function open(): void { host.showPopover(); }
        function hide(): void { host.hidePopover(); }
        function toggle(): void { host.togglePopover(); }
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
        implicitWidth: host.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        color: "transparent"
        mask: Region { item: popoverVisualSurface }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: host.layerNamespace
        anchors { top: true; left: true }
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
            retainLoaded: host.retainContentLoaded
            content: host.content
        }
    }

    FloatingWindow {
        id: floatingWindow
        visible: host.floatingMode
        implicitWidth: host.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        title: host.windowTitle
        color: "transparent"
        mask: Region { item: floatingVisualSurface }
        onWindowConnected: host.requestWindowPlacement()
        onVisibleChanged: if (visible) {
            Qt.callLater(host.requestWindowPlacement);
            Qt.callLater(host.focusSearchRequested);
        }

        VisualSurface {
            id: floatingVisualSurface
            surfaceWidth: host.surfaceWindowWidth
            contentWidth: host.currentWindowWidth
            loadWhen: host.floatingMode
            retainLoaded: host.retainContentLoaded
            content: host.content
        }
    }

    HyprlandFocusGrab {
        active: Theme.hyprland && host.popoverMode && host.popoverVisible
        windows: [popoverAnchor]
        onCleared: if (!host.retainOnFocusLoss) host.hidePopover()
    }
}
