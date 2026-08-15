pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property BluetoothController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property bool editingDetails: chooser.detailsItem ? chooser.detailsItem.editingText : false

    Shortcut {
        sequence: "F5"
        enabled: content.controller.powered && !content.controller.refreshInFlight
            && !content.controller.actionInFlight && !content.controller.modalPromptOpen
            && !content.controller.navigationHelpOpen && !content.editingDetails
        onActivated: content.controller.toggleScan()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection
            && !content.controller.modalPromptOpen && !content.controller.navigationHelpOpen
            && !content.editingDetails
        onActivated: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.modalPromptOpen && !content.controller.navigationHelpOpen
            && !content.editingDetails
        onActivated: content.controller.dismissNavigation()
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
        helpEnabled: !content.controller.modalPromptOpen && !content.editingDetails
        entries: [
            { keys: "F5", action: "Refresh devices or toggle discovery" },
            { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
        ]
    }
}
