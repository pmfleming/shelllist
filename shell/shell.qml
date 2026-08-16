pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Bar as Bar

ShellRoot {
    id: shell

    readonly property Ui.ChooserController activeController: surfaces.currentController

    function selectSurface(surfaceId: string): bool {
        const requested = surfaces.validSurfaceId(surfaceId);
        if (requested.length === 0)
            return false;

        const previousId = surfaces.currentId;
        const previousController = surfaces.currentController;
        if (!surfaces.select(requested))
            return false;

        if (windowHost.uiActive && previousId !== surfaces.currentId) {
            if (previousController)
                previousController.deactivateUi();
            if (activeController)
                activeController.activateUi(windowHost.shelllistWorkspaceId());
        }
        return true;
    }

    function openSurface(surfaceId: string): bool {
        if (!selectSurface(surfaceId))
            return false;
        if (windowHost.popoverMode && !windowHost.popoverVisible)
            windowHost.show();
        else if (activeController)
            activeController.focusSearchRequested();
        return true;
    }

    function toggleSurface(surfaceId: string): bool {
        const requested = surfaces.validSurfaceId(surfaceId);
        if (requested.length === 0)
            return false;
        if (windowHost.popoverMode && windowHost.popoverVisible
                && surfaces.currentId === requested) {
            windowHost.hide();
            return true;
        }
        return openSurface(requested);
    }

    function cycleSurface(direction: int): void {
        if (!windowHost.uiActive || !activeController || activeController.navigationBlocked
                || activeController.navigationHelpOpen)
            return;
        const ids = surfaces.descriptors.map(function (descriptor) { return descriptor.id; });
        const currentIndex = Math.max(0, ids.indexOf(surfaces.currentId));
        const nextIndex = (currentIndex + direction + ids.length) % ids.length;
        openSurface(ids[nextIndex]);
    }

    SurfaceRegistry {
        id: surfaces
        onSurfaceRequested: function (surfaceId) { shell.openSurface(surfaceId); }
    }

    Bar.BarController {
        id: barController
        surfaceRegistry: surfaces
    }

    Variants {
        model: windowHost.popoverMode ? Quickshell.screens : []

        Bar.BarWindow {
            required property var modelData
            targetScreen: modelData
            controller: barController
        }
    }

    Ui.PopupWindowHost {
        id: windowHost

        content: shellContentComponent
        surfaceWindowWidth: shell.activeController
            ? shell.activeController.surfaceWindowWidth : Ui.Theme.popupOpenWidth
        currentWindowWidth: shell.activeController
            ? shell.activeController.currentWindowWidth : Ui.Theme.popupClosedWidth
        modeEnvironment: "SHELLLIST_MODE"
        ipcTarget: "shelllist-window"
        ipcEnabled: false
        shortcutName: "shell"
        shortcutDescription: "Toggle Shelllist"
        shortcutEnabled: false
        windowTitle: "Shelllist"
        layerNamespace: "shelllist"
        retainContentLoaded: true
        retainOnFocusLoss: shell.activeController
            ? shell.activeController.navigationBlocked : false

        onUiActivated: function (workspaceId) {
            if (shell.activeController)
                shell.activeController.activateUi(workspaceId);
        }
        onUiDeactivated: if (shell.activeController) shell.activeController.deactivateUi()
        onFocusSearchRequested: if (shell.activeController) shell.activeController.focusSearchRequested()
    }

    Component {
        id: shellContentComponent
        ShellContent { registry: surfaces }
    }

    Connections {
        target: shell.activeController
        ignoreUnknownSignals: true

        function onCloseWindowRequested() { windowHost.closeRequested(); }
        function onScreenshotRequested() {
            const controller = shell.activeController;
            if (!controller)
                return;
            const width = Math.round(controller.currentWindowWidth);
            const x = Math.round(windowHost.targetWindowX()
                + (controller.surfaceWindowWidth - width) / 2);
            controller.captureScreenshot(x, windowHost.targetWindowY(), width,
                windowHost.currentWindowHeight);
        }
    }

    IpcHandler {
        enabled: windowHost.popoverMode
        target: "shelllist"

        function ping(): string { return "pong"; }
        function open(surfaceId: string): string {
            return shell.openSurface(surfaceId) ? "ok" : "unknown-surface";
        }
        function toggle(surfaceId: string): string {
            return shell.toggleSurface(surfaceId) ? "ok" : "unknown-surface";
        }
        function hide(): void { windowHost.hide(); }
        function quit(): void {
            if (shell.activeController)
                shell.activeController.deactivateUi();
            Qt.quit();
        }
        function status(): string {
            return JSON.stringify({
                visible: windowHost.popoverMode ? windowHost.popoverVisible : windowHost.uiActive,
                surface: surfaces.currentId,
                loaded: surfaces.loadedSurfaces,
                opened: surfaces.openedSurfaces
            });
        }
        function listSurfaces(): string { return surfaces.listJson(); }
    }

    Ui.ShelllistGlobalShortcut {
        shortcutName: "applications"
        description: "Toggle Shelllist Applications"
        onTriggered: shell.toggleSurface("applications")
    }
    Ui.ShelllistGlobalShortcut {
        shortcutName: "wifi"
        description: "Toggle Shelllist Wi-Fi"
        onTriggered: shell.toggleSurface("wifi")
    }
    Ui.ShelllistGlobalShortcut {
        shortcutName: "bluetooth"
        description: "Toggle Shelllist Bluetooth"
        onTriggered: shell.toggleSurface("bluetooth")
    }
    Ui.ShelllistGlobalShortcut {
        shortcutName: "clipboard"
        description: "Toggle Shelllist Clipboard"
        onTriggered: shell.toggleSurface("clipboard")
    }

    Shortcut {
        sequence: "Ctrl+Alt+Right"
        enabled: windowHost.uiActive
        onActivated: shell.cycleSurface(1)
    }
    Shortcut {
        sequence: "Ctrl+Alt+Left"
        enabled: windowHost.uiActive
        onActivated: shell.cycleSurface(-1)
    }
}
