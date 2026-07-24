pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    ClipboardController { id: clipboardController }

    Ui.ChooserWindowHost {
        id: windowHost
        controller: clipboardController
        applicationId: "clipboard"
        displayName: "Clipboard"
        content: contentComponent
    }

    Connections {
        target: clipboardController
        function onScreenshotRequested() {
            const width = Math.round(clipboardController.currentWindowWidth);
            const x = Math.round(windowHost.targetWindowX()
                + (clipboardController.surfaceWindowWidth - width) / 2);
            clipboardController.captureScreenshot(x, windowHost.targetWindowY(), width, windowHost.currentWindowHeight);
        }
    }

    Component {
        id: contentComponent
        ClipboardContent { controller: clipboardController }
    }
}
