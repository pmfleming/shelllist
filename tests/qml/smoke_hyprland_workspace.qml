import Quickshell
import Quickshell.Hyprland
import QtQuick
import Shelllist.Ui as Ui

// Opt-in integration probe: use only with a private 0.57 compositor containing
// ordinary workspace 6 and an open special:ipc-probe workspace.
ShellRoot {
    Ui.PopupWindowHost {
        id: host
        content: Component { Item {} }
        geometry: Ui.PopoverGeometry {}
        currentWindowWidth: 400
        modeEnvironment: "SHELLLIST_IPC_TEST_MODE"
        defaultLaunchMode: "popover"
        ipcTarget: "shelllist-ipc-workspace-test"
        shortcutName: "ipc-workspace-test"
        shortcutDescription: "Private workspace test"
        windowTitle: "Private hidden workspace test"
        layerNamespace: "shelllist-ipc-workspace-test"
        ipcEnabled: false
        shortcutEnabled: false
    }

    Timer {
        property int attempts: 0
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            const special = Hyprland.workspaces.values.find(function (workspace) {
                return workspace.address === "special:ipc-probe";
            });
            if (!Hyprland.focusedWorkspace || !special) {
                if (++attempts < 200)
                    return;
                console.error("Private compositor workspace state did not arrive");
                Qt.exit(1);
                return;
            }
            // Quickshell keeps focusedWorkspace on the numbered active workspace
            // even while a special workspace is open. Popup activation remains 6.
            if (special.id !== -1 || host.shelllistWorkspaceId() !== "6"
                    || host.popoverWindowVisible || host.uiActive) {
                console.error("Special identity or hidden popup context is incorrect");
                Qt.exit(1);
                return;
            }
            console.log("PASS: numberless special workspace and hidden popup context");
            Qt.quit();
        }
    }
}
