pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    ClipboardController { id: clipboardController }

    Ui.ChooserWindowHost {
        controller: clipboardController
        applicationId: "clipboard"
        displayName: "Clipboard"
        content: contentComponent
    }


    Component {
        id: contentComponent
        ClipboardContent { controller: clipboardController }
    }
}
