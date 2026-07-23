pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property BluetoothController controller
    required property Ui.PopupWindowHost windowHost
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property bool editingDetails: chooser.detailsItem ? chooser.detailsItem.editingText : false

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(chooser.listItem.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(chooser.listItem.focusTop); }
    }

    Shortcut { sequence: "F5"; enabled: content.controller.powered && !content.controller.refreshInFlight && !content.controller.actionInFlight && !content.controller.modalPromptOpen && !content.editingDetails; onActivated: content.controller.toggleScan() }
    Shortcut {
        sequence: "Alt+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection && !content.controller.modalPromptOpen && !content.editingDetails
        onActivated: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection && !content.controller.modalPromptOpen && !content.editingDetails
        onActivated: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.modalPromptOpen && !content.editingDetails
        onActivated: {
            if (content.controller.canCancelTransfer)
                content.controller.cancelActiveTransfer();
            else if (content.controller.canCancelOperation)
                content.controller.cancelActiveOperation();
            else if (content.controller.detailsOpen)
                content.controller.detailsOpen = false;
            else
                content.windowHost.closeRequested();
        }
    }

    Ui.SplitChooserLayout {
        id: chooser
        controller: content.controller
        listComponent: Component {
            BluetoothDeviceListPane {
                controller: content.controller
                uiScale: content.uiScale
            }
        }
        detailsComponent: Component {
            BluetoothDeviceDetails {
                controller: content.controller
                uiScale: content.uiScale
            }
        }
    }

    BluetoothPairingPrompt { controller: content.controller }
    BluetoothObexPrompt { controller: content.controller }
    Ui.ConfirmationDialog {
        visible: content.controller.confirmationOpen
        z: 120
        title: (content.controller.pendingConfirmationAction || ({})).confirmation
            ? content.controller.pendingConfirmationAction.confirmation.title : "Confirm Bluetooth action"
        detail: (content.controller.pendingConfirmationAction || ({})).confirmation
            ? content.controller.pendingConfirmationAction.confirmation.message : "This action cannot be undone."
        acceptLabel: "Forget"
        onAccepted: content.controller.confirmPendingAction()
        onCancelled: content.controller.cancelPendingConfirmation()
    }
}
