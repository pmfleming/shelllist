import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: content

    required property BluetoothController controller
    required property BluetoothWindowHost windowHost

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.window
    border.color: Ui.Theme.strongBorder
    border.width: 1

    function toggleDetails() {
        if (controller.hasSelection)
            controller.detailsOpen = !controller.detailsOpen;
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(devicePane.focusSearch); }
    }

    Shortcut { sequence: "Up"; enabled: !content.controller.modalPromptOpen; onActivated: content.controller.moveSelection(-1) }
    Shortcut { sequence: "Down"; enabled: !content.controller.modalPromptOpen; onActivated: content.controller.moveSelection(1) }
    Shortcut {
        sequence: "Enter"
        enabled: !detailsPane.confirmRemove && !content.controller.modalPromptOpen && !detailsPane.editingName
        onActivated: content.controller.primarySelected()
    }
    Shortcut { sequence: "Right"; enabled: content.controller.hasSelection && !content.controller.modalPromptOpen; onActivated: content.controller.detailsOpen = true }
    Shortcut { sequence: "Left"; enabled: content.controller.detailsOpen && !content.controller.modalPromptOpen; onActivated: content.controller.detailsOpen = false }
    Shortcut { sequence: "F5"; enabled: !content.controller.modalPromptOpen; onActivated: content.controller.toggleScan() }
    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.modalPromptOpen
        onActivated: {
            if (content.controller.canCancelTransfer)
                content.controller.cancelActiveTransfer();
            else if (content.controller.canCancelOperation)
                content.controller.cancelActiveOperation();
            else if (detailsPane.confirmRemove)
                detailsPane.cancelRemove();
            else if (content.controller.detailsOpen)
                content.controller.detailsOpen = false;
            else
                content.windowHost.closeRequested();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        BluetoothDeviceListPane {
            id: devicePane
            controller: content.controller
        }
        BluetoothDeviceDetails {
            id: detailsPane
            controller: content.controller
        }
    }

    BluetoothPairingPrompt { controller: content.controller }
    BluetoothObexPrompt { controller: content.controller }
}
