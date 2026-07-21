import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: content

    required property BluetoothController controller
    required property BluetoothWindowHost windowHost
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.window
    border.color: Ui.Theme.strongBorder
    border.width: 1

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(devicePane.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(devicePane.focusTop); }
    }

    Shortcut { sequence: "F5"; enabled: content.controller.powered && !content.controller.actionInFlight && !content.controller.modalPromptOpen && !detailsPane.editingText; onActivated: content.controller.toggleScan() }
    Shortcut {
        sequence: "Alt+Tab"
        enabled: content.controller.detailsOpen
            && content.controller.hasSelection
            && !content.controller.modalPromptOpen
            && !detailsPane.editingText
        onActivated: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen
            && content.controller.hasSelection
            && !content.controller.modalPromptOpen
            && !detailsPane.editingText
        onActivated: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.modalPromptOpen && !detailsPane.editingText
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: content.controller.contentMargin
        anchors.rightMargin: content.controller.contentMargin
        anchors.topMargin: content.controller.contentVerticalMargin
        anchors.bottomMargin: content.controller.contentVerticalMargin
        spacing: 0

        BluetoothDeviceListPane {
            id: devicePane
            controller: content.controller
            uiScale: content.uiScale
            Layout.preferredWidth: content.controller.listPaneWidth
            Layout.minimumWidth: content.controller.listPaneWidth
            Layout.maximumWidth: content.controller.listPaneWidth
        }

        Item {
            visible: content.controller.detailsRendered
            Layout.preferredWidth: content.controller.detailsPaneGapWidth
            Layout.minimumWidth: content.controller.detailsPaneGapWidth
            Layout.maximumWidth: content.controller.detailsPaneGapWidth
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Ui.Theme.border
                opacity: 0.75
            }
        }

        BluetoothDeviceDetails {
            id: detailsPane
            controller: content.controller
            uiScale: content.uiScale
            visible: content.controller.detailsRendered
            Layout.preferredWidth: content.controller.detailsPaneWidth
            Layout.minimumWidth: content.controller.detailsPaneWidth
            Layout.maximumWidth: content.controller.detailsPaneWidth
            Layout.fillHeight: true
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
        onAccepted: content.controller.confirmPendingAction()
        onCancelled: content.controller.cancelPendingConfirmation()
    }
}
