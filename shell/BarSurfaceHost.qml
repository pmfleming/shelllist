pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Bar as Bar
import "BarSurfaceRecovery.js" as Recovery

Item {
    id: root

    required property Bar.BarController controller
    property bool barsEnabled: true
    property bool surfacesActive: false
    property string lastScreenSignature: ""
    property double lastHeartbeatMs: 0
    property bool initialized: false
    property bool recoveryCoolingDown: false
    property bool recoveryPending: false
    property string recoveryReason: ""

    function currentScreenSignature(): string {
        return Recovery.screenSignature(Quickshell.screens);
    }

    function hasUsableScreen(): bool {
        return currentScreenSignature().length > 0;
    }

    function scheduleRecovery(reason: string): void {
        if (!barsEnabled || !hasUsableScreen())
            return;
        recoveryReason = reason;
        if (recoveryCoolingDown) {
            recoveryPending = true;
            return;
        }
        recoveryDebounce.restart();
    }

    function observeScreens(): void {
        const signature = currentScreenSignature();
        if (!initialized) {
            initialized = true;
            lastScreenSignature = signature;
            return;
        }
        if (signature === lastScreenSignature)
            return;
        const previous = lastScreenSignature;
        lastScreenSignature = signature;
        if (signature.length > 0)
            scheduleRecovery(previous.length === 0 ? "screen-reconnected" : "screens-changed");
    }

    function rebuildSurfaces(): void {
        if (!barsEnabled || !hasUsableScreen())
            return;
        console.info("Shelllist rebuilding bar surfaces after " + recoveryReason);
        surfacesActive = false;
        surfaceRestore.restart();
    }

    onBarsEnabledChanged: {
        if (!barsEnabled) {
            recoveryDebounce.stop();
            surfaceRestore.stop();
            surfacesActive = false;
        } else {
            surfacesActive = true;
            observeScreens();
        }
    }

    Component.onCompleted: {
        surfacesActive = barsEnabled;
        lastHeartbeatMs = Date.now();
        observeScreens();
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void { root.observeScreens(); }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.barsEnabled
        onTriggered: {
            const current = Date.now();
            if (Recovery.heartbeatIndicatesResume(root.lastHeartbeatMs, current,
                    interval, 6000))
                root.scheduleRecovery("session-resumed");
            root.observeScreens();
            root.lastHeartbeatMs = current;
        }
    }

    Timer {
        id: recoveryDebounce
        interval: 450
        repeat: false
        onTriggered: {
            root.recoveryCoolingDown = true;
            root.recoveryPending = false;
            recoveryCooldown.restart();
            root.rebuildSurfaces();
        }
    }

    Timer {
        id: surfaceRestore
        interval: 50
        repeat: false
        onTriggered: root.surfacesActive = root.barsEnabled && root.hasUsableScreen()
    }

    Timer {
        id: recoveryCooldown
        interval: 4000
        repeat: false
        onTriggered: {
            root.recoveryCoolingDown = false;
            if (root.recoveryPending) {
                root.recoveryPending = false;
                recoveryDebounce.restart();
            }
        }
    }

    Variants {
        model: root.barsEnabled && root.surfacesActive ? Quickshell.screens : []

        Bar.BarWindow {
            required property var modelData
            targetScreen: modelData
            controller: root.controller
        }
    }

    Variants {
        model: root.barsEnabled && root.surfacesActive ? Quickshell.screens : []

        Bar.BarOsdWindow {
            required property var modelData
            targetScreen: modelData
            controller: root.controller
        }
    }

    Variants {
        model: root.barsEnabled && root.surfacesActive ? Quickshell.screens : []

        Bar.NotificationToastWindow {
            required property var modelData
            targetScreen: modelData
            controller: root.controller
        }
    }
}
