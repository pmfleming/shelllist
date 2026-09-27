pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property BluetoothController controller
    chooserController: controller
    readonly property bool editingDetails: (detailsItem as BluetoothDeviceDetails)?.editingText ?? false
    keyboardWorkflow: true
    navigationEnabled: !controller.modalPromptOpen
    detailsTabEnabled: navigationEnabled && controller.detailsOpen && (controller.hasSelection || controller.detailsTab === "adapter")
    refreshEnabled: controller.powered && !controller.refreshInFlight && !controller.actionInFlight && navigationEnabled && !editingDetails

    function refresh(): void {
        controller.toggleScan();
    }

    listComponent: Component {
        BluetoothDeviceListPane {
            controller: content.controller
        }
    }
    detailsComponent: Component {
        BluetoothDeviceDetails {
            controller: content.controller
            uiScale: content.uiScale
        }
    }

    BluetoothPairingPrompt {
        controller: content.controller
    }

    Ui.ConfirmationDialog {
        visible: content.controller.confirmationOpen
        z: 120
        title: (content.controller.pendingConfirmationAction || ({})).confirmation ? content.controller.pendingConfirmationAction.confirmation.title : "Confirm Bluetooth action"
        detail: (content.controller.pendingConfirmationAction || ({})).confirmation ? content.controller.pendingConfirmationAction.confirmation.message : "This action cannot be undone."
        acceptLabel: "Forget"
        onAccepted: content.controller.confirmPendingAction()
        onCancelled: content.controller.cancelPendingConfirmation()
    }
}
