pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    BluetoothController {
        id: controller
        onIncomingTransferRequested: windowHost.show()
    }

    Ui.PopupWindowHost {
        id: windowHost
        modeEnvironment: "SHELLLIST_BLUETOOTH_MODE"
        ipcTarget: "bluetooth"
        shortcutName: "bluetooth"
        shortcutDescription: "Toggle the Shelllist Bluetooth chooser"
        windowTitle: "Shelllist Bluetooth"
        layerNamespace: "shelllist-bluetooth"
        content: contentComponent
        surfaceWindowWidth: controller.surfaceWindowWidth
        currentWindowWidth: controller.currentWindowWidth
        onUiActivated: function (workspaceId) { controller.activateUi(workspaceId); }
        onUiDeactivated: controller.deactivateUi()
        onFocusSearchRequested: controller.focusSearchRequested()
    }

    Component {
        id: contentComponent
        BluetoothContent { controller: controller; windowHost: windowHost }
    }

}
