// Quickshell 0.3's GlobalShortcut qmltypes expose an internal PostReloadHook base without
// exporting it. Keep that private compatibility import isolated in this adapter.
// qmllint disable import
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts // qmllint disable import
import QtQuick

Item {
    id: shortcut

    signal triggered

    GlobalShortcut { // qmllint disable unresolved-type import
        appid: "shelllist"
        name: "bluetooth"
        description: "Toggle the Shelllist Bluetooth chooser"
        onPressed: shortcut.triggered()
    }
}
