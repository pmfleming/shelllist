pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property BluetoothController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property bool editingDetails: chooser.detailsItem ? chooser.detailsItem.editingText : false

    Ui.ChooserShortcuts {
        controller: content.controller
        navigationEnabled: !content.controller.modalPromptOpen
            && !content.controller.navigationHelpOpen && !content.editingDetails
        refreshEnabled: content.controller.powered && !content.controller.refreshInFlight
            && !content.controller.actionInFlight && navigationEnabled
        detailsTabEnabled: content.controller.detailsOpen && content.controller.hasSelection
            && navigationEnabled
        onRefreshRequested: content.controller.toggleScan()
        onDetailsTabRequested: content.controller.cycleDetailsTab()
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

    Ui.NavigationHelpDialog {
        controller: content.controller
        surfaceName: "Bluetooth"
        helpEnabled: content.controller.uiActive && !content.controller.modalPromptOpen
            && !content.editingDetails
        entries: [
            { keys: "F5", action: "Refresh devices or toggle discovery" },
            { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
        ]
    }
}
