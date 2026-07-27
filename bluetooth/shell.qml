pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    BluetoothController {
        id: bluetoothController
        onIncomingTransferRequested: windowHost.show()
    }

    Ui.ChooserWindowHost {
        id: windowHost
        controller: bluetoothController
        applicationId: "bluetooth"
        displayName: "Bluetooth"
        content: contentComponent
    }

    Connections {
        target: bluetoothController
        function onScreenshotRequested() {
            const width = Math.round(bluetoothController.currentWindowWidth);
            const x = Math.round(windowHost.targetWindowX()
                + (bluetoothController.surfaceWindowWidth - width) / 2);
            bluetoothController.captureScreenshot(x, windowHost.targetWindowY(), width, windowHost.currentWindowHeight);
        }
    }

    Component {
        id: contentComponent
        BluetoothContent { controller: bluetoothController }
    }
}
