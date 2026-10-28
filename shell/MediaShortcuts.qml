import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui

// Register once in the resident shell, not once per monitor's media chip.
// The compositor owns key bindings; no panel/editor keys are intercepted here.
Item {
    id: shortcuts
    required property Bar.BarController controller

    Ui.ShelllistGlobalShortcut {
        shortcutName: "media-play-pause"
        description: "Play or Pause Bar Media"
        onTriggered: shortcuts.controller.performMediaTransport("play-pause")
    }
    Ui.ShelllistGlobalShortcut {
        shortcutName: "media-back"
        description: "Previous Track or Rewind Bar Media"
        onTriggered: shortcuts.controller.performMediaTransport("back")
    }
    Ui.ShelllistGlobalShortcut {
        shortcutName: "media-forward"
        description: "Next Track or Fast-forward Bar Media"
        onTriggered: shortcuts.controller.performMediaTransport("forward")
    }
}
