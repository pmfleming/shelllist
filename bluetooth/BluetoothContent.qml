pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property BluetoothController controller
    chooserController: controller
    surfaceName: "Bluetooth"
    readonly property bool editingDetails: detailsItem ? detailsItem.editingText : false
    navigationEnabled: !controller.modalPromptOpen
        && !controller.navigationHelpOpen && !editingDetails
    refreshEnabled: controller.powered && !controller.refreshInFlight
        && !controller.actionInFlight && navigationEnabled
    detailsTabEnabled: controller.detailsOpen && controller.hasSelection
        && navigationEnabled
    helpEnabled: controller.uiActive && !controller.modalPromptOpen && !editingDetails
    helpEntries: [
        { keys: "F5", action: "Refresh devices or toggle discovery" },
        { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
    ]
    onRefreshRequested: controller.toggleScan()
    onDetailsTabRequested: controller.cycleDetailsTab()

    listComponent: Component {
        BluetoothDeviceListPane { controller: content.controller }
    }
    detailsComponent: Component {
        BluetoothDeviceDetails { controller: content.controller; uiScale: content.uiScale }
    }

    BluetoothPairingPrompt { controller: content.controller }

    Ui.ConfirmationDialog {
        visible: content.controller.confirmationOpen
        z: 120
        title: (content.controller.pendingConfirmationAction || ({})).confirmation
            ? content.controller.pendingConfirmationAction.confirmation.title
            : "Confirm Bluetooth action"
        detail: (content.controller.pendingConfirmationAction || ({})).confirmation
            ? content.controller.pendingConfirmationAction.confirmation.message
            : "This action cannot be undone."
        acceptLabel: "Forget"
        onAccepted: content.controller.confirmPendingAction()
        onCancelled: content.controller.cancelPendingConfirmation()
    }
}
