pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

ShellRoot {
    BluetoothController {
        id: controller
        onIncomingTransferRequested: windowHost.show()
    }

    BluetoothWindowHost {
        id: windowHost
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
