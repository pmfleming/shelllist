// Quickshell 0.3 exposes GlobalShortcut through a private module whose qmltypes
// omit the internal PostReloadHook dependency. The lint check suppresses only
// that upstream import diagnostic for this adapter.
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import QtQuick

Item {
    id: shortcut

    required property string shortcutName
    required property string description
    signal triggered

    GlobalShortcut { // qmllint disable unresolved-type import
        appid: "shelllist"
        name: shortcut.shortcutName
        description: shortcut.description
        onPressed: shortcut.triggered()
    }
}
