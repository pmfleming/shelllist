import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

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
    property int popoverNoAnimRuleState: -1
    property string pendingPopoverLayerRule: ""

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

    function popoverAnimationRuleReady(desiredState) {
        return popoverMode && Theme.hyprland && popoverNoAnimRuleState !== desiredState;
    }
    function syncPopoverAnimationRule() {
        const desiredState = noAnimations ? 1 : 0;
        if (!popoverAnimationRuleReady(desiredState))
            return;
        applyPopoverLayerAnimationRule(noAnimations
            ? "animation 0 " + layerNamespace
            : "animation unset " + layerNamespace);
        popoverNoAnimRuleState = desiredState;
    }
    function applyPopoverLayerAnimationRule(rule) {
        if (popoverLayerRuleProcess.running) {
            pendingPopoverLayerRule = rule;
            return;
        }
        popoverLayerRuleProcess.exec(["hyprctl", "keyword", "layerrule", rule]);
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
        const selector = "title:" + windowTitle;
        Hyprland.dispatch("setprop " + selector + " noanim " + (noAnimations ? "1" : "0"));
        Hyprland.dispatch("setprop " + selector + " noborder 1");
        Hyprland.dispatch("setprop " + selector + " noshadow 1");
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
            Hyprland.dispatch("focuswindow " + selector);
            Hyprland.dispatch("setfloating");
            Hyprland.dispatch("movewindowpixel exact " + host.targetWindowX() + " " + host.targetWindowY() + "," + selector);
        }
    }

    onNoAnimationsChanged: syncPopoverAnimationRule()
    Component.onCompleted: if (floatingMode) Qt.callLater(function () {
        host.uiActivated(host.shelllistWorkspaceId());
        host.focusSearchRequested();
    })

    Process {
        id: popoverLayerRuleProcess
        onExited: function () { host.runPendingPopoverLayerRule(); } // qmllint disable signal-handler-parameters
    }

    IpcHandler {
        enabled: host.popoverMode
        target: host.ipcTarget
        readonly property bool visible: host.popoverVisible
        function ping(): string { return "pong"; }
        function status(): string { return host.popoverVisible ? "visible" : "hidden"; }
        function open(): void { host.showPopover(); }
        function hide(): void { host.hidePopover(); }
        function toggle(): void { host.togglePopover(); }
    }

    ShelllistGlobalShortcut {
        shortcutName: host.shortcutName
        description: host.shortcutDescription
        onTriggered: host.togglePopover()
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
            content: host.content
        }
    }

    HyprlandFocusGrab {
        active: Theme.hyprland && host.popoverMode && host.popoverVisible
        windows: [popoverAnchor]
        onCleared: host.hidePopover()
    }
}
