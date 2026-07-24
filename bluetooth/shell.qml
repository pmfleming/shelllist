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

    Component {
        id: contentComponent
        BluetoothContent { controller: bluetoothController }
    }
}
