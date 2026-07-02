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
    readonly property bool floatingWindowVisible: floatingMode
    readonly property bool popoverWindowVisible: popoverMode && popoverVisible
    property bool popoverVisible: false
    property bool windowNoAnimRule: false
    property int floatingPlacementAttempts: 0
    readonly property bool noAnimations: Theme.noAnimations
    readonly property var placementScreen: floatingMode
        ? (wifiWindow && wifiWindow.screen ? wifiWindow.screen : null)
        : (popoverAnchor && popoverAnchor.screen ? popoverAnchor.screen : null)
    readonly property int currentWindowHeight: Math.round((((placementScreen && placementScreen.height > 0) ? placementScreen.height : 960) * 0.75))

    function targetWindowX() {
        const screen = placementScreen;
        const screenX = screen ? screen.x || 0 : 0;
        const screenWidth = screen && screen.width > 0 ? screen.width : 1280;
        return Math.round(screenX + (screenWidth - controller.surfaceWindowWidth) / 2);
    }

    function targetWindowY() {
        const screen = placementScreen;
        const screenY = screen ? screen.y || 0 : 0;
        const screenHeight = screen && screen.height > 0 ? screen.height : 960;
        return Math.round(screenY + (screenHeight - currentWindowHeight) / 2);
    }

    function targetLayerMarginX() {
        const screen = placementScreen;
        const screenWidth = screen && screen.width > 0 ? screen.width : 1280;
        return Math.round((screenWidth - controller.surfaceWindowWidth) / 2);
    }

    function targetLayerMarginY() {
        const screen = placementScreen;
        const screenHeight = screen && screen.height > 0 ? screen.height : 960;
        return Math.round((screenHeight - currentWindowHeight) / 2);
    }

    function requestFloatingPlacement() {
        if (!floatingMode || !floatingWindowVisible || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return;
        floatingPlacementAttempts = 0;
        floatingPlacementTimer.restart();
    }

    function requestPopoverReposition() {
        // The popover is a centered PanelWindow; Quickshell reapplies the
        // margins and implicit size as bindings change.
    }

    function requestWindowPlacement() {
        if (popoverMode)
            requestPopoverReposition();
        else
            requestFloatingPlacement();
    }

    function refreshWindowNoAnimRule() {
        if (!floatingMode || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || noAnimPropProc.running)
            return;
        noAnimPropProc.exec(["hyprctl", "-j", "getprop", "title:Shelllist.*", "no_anim"]);
    }

    function applyCompositorNoAnimRule() {
        if (!floatingMode || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return;
        Hyprland.dispatch("setprop title:Shelllist.* noanim 1");
        Hyprland.dispatch("setprop title:Shelllist.* noborder 1");
        Hyprland.dispatch("setprop title:Shelllist.* noshadow 1");
        windowNoAnimRule = true;
    }

    function applyWindowNoAnimRule(text) {
        try {
            const value = JSON.parse(text).no_anim;
            windowNoAnimRule = value === true || value === 1 || value === "true" || value === "1";
        } catch (error) {
            windowNoAnimRule = /(?:^|\s)(true|1)(?:\s|$)/i.test(text);
        }
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
        popoverVisible = true;
        controller.refresh();
        Qt.callLater(requestPopoverReposition);
        Qt.callLater(controller.focusSearchBox);
    }

    function hidePopover() {
        if (popoverMode)
            popoverVisible = false;
    }

    function togglePopover() { popoverVisible ? hidePopover() : showPopover(); }
    function ping(): string { return "pong"; }

    Timer {
        id: floatingPlacementTimer
        interval: 16
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            host.floatingPlacementAttempts += 1;
            if (host.floatingPlacementAttempts === 1) {
                host.applyCompositorNoAnimRule();
                host.refreshWindowNoAnimRule();
            }
            Hyprland.dispatch("focuswindow title:Shelllist Wi-Fi");
            Hyprland.dispatch("setfloating");
            // Qt owns the toplevel size through FloatingWindow.implicitWidth/Height.
            // Keep Hyprland placement limited to moving the already-rendered surface;
            // forcing compositor-side resizes here can expose an unpainted region
            // before Qt commits the matching frame.
            Hyprland.dispatch("movewindowpixel exact " + host.targetWindowX() + " " + host.targetWindowY() + ",title:Shelllist Wi-Fi");
            if (host.floatingPlacementAttempts >= 24)
                stop();
        }
    }

    Process {
        id: noAnimPropProc
        stdout: StdioCollector {
            id: noAnimPropOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0)
                host.applyWindowNoAnimRule(noAnimPropOut.text);
        }
    }

    IpcHandler {
        enabled: host.popoverMode
        target: "wifi"
        readonly property bool visible: host.popoverVisible
        function ping(): string { return host.ping(); }
        function open(): void { host.showPopover(); }
        function hide(): void { host.hidePopover(); }
        function toggle(): void { host.togglePopover(); }
    }

    // Quickshell's generated type info marks PanelWindow as an interface and
    // does not give the linter enough information for its margins group.
    // qmllint disable uncreatable-type unresolved-type unqualified
    PanelWindow {
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
        margins {
            top: host.targetLayerMarginY()
            left: host.targetLayerMarginX()
        }
        onVisibleChanged: if (visible) Qt.callLater(host.controller.focusSearchBox)

        Item {
            id: popoverVisualSurface
            x: Math.round((host.controller.surfaceWindowWidth - host.controller.currentWindowWidth) / 2)
            y: 0
            width: host.controller.currentWindowWidth
            height: parent.height
            clip: true

            SurfaceLoader { loadWhen: host.popoverWindowVisible; content: host.content }
        }
    }

    // qmllint enable uncreatable-type unresolved-type unqualified
    FloatingWindow {
        id: wifiWindow
        visible: host.floatingWindowVisible
        implicitWidth: host.controller.surfaceWindowWidth
        implicitHeight: host.currentWindowHeight
        title: "Shelllist Wi-Fi"
        // Keep the real toplevel at the maximum size and transparent; the
        // clipped visual surface below paints the actual rounded popup. This
        // avoids compositor resize artifacts during details-pane transitions.
        color: "transparent"
        mask: Region { item: floatingVisualSurface }
        onWindowConnected: {
            host.requestFloatingPlacement();
            Qt.callLater(host.refreshWindowNoAnimRule);
        }
        onVisibleChanged: if (visible) Qt.callLater(host.requestFloatingPlacement)

        Item {
            id: floatingVisualSurface
            x: Math.round((host.controller.surfaceWindowWidth - host.controller.currentWindowWidth) / 2)
            y: 0
            width: host.controller.currentWindowWidth
            height: parent.height
            clip: true

            SurfaceLoader { loadWhen: host.floatingWindowVisible; content: host.content }
        }
    }

    HyprlandFocusGrab {
        active: host.popoverMode && host.popoverVisible
        windows: [popoverAnchor]
        onCleared: host.hidePopover()
    }
}
