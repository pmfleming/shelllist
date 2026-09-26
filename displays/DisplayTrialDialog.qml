pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ModalFrame {
    id: dialog
    required property DisplayController controller
    objectName: "displayTrialDialog"
    title: qsTr("Keep this layout?")
    maximumCardWidth: 420
    visible: !!controller.trial
    detail: controller.displayPolicyError || (controller.stale ? qsTr("Displays changed. Revert this layout.") : "")

    ColumnLayout {
        width: parent.width
        spacing: Ui.Theme.spacingMd
        Ui.ThemeText {
            Layout.alignment: Qt.AlignHCenter
            text: dialog.controller.secondsLeft > 0 ? dialog.controller.secondsLeft + " s" : qsTr("Reverting…")
            color: Ui.Theme.warning
            font.pixelSize: Ui.Theme.fontSizeDisplay
            font.weight: Ui.Theme.fontWeightBold
            Accessible.name: qsTr("Automatic revert countdown")
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Ui.Theme.border
            Rectangle {
                width: parent.width * Math.min(1, dialog.controller.secondsLeft / 20)
                height: parent.height
                radius: 2
                color: Ui.Theme.warning
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingMd
            Ui.ActionButton {
                id: revert
                objectName: "revertDisplayLayout"
                Layout.fillWidth: true
                label: qsTr("Revert")
                icon: "󰕍"
                enabled: dialog.controller.backend.ready && !dialog.controller.actionInFlight
                onClicked: if (dialog.controller.trial)
                    dialog.controller.displayLayoutAction("revert", {
                        id: dialog.controller.trial.id
                    })
            }
            Ui.ActionButton {
                objectName: "confirmDisplayLayout"
                Layout.fillWidth: true
                label: qsTr("Keep")
                icon: "󰄬"
                tone: "accent"
                enabled: dialog.controller.backend.ready && !dialog.controller.actionInFlight && !dialog.controller.stale && dialog.controller.secondsLeft > 0
                onClicked: if (dialog.controller.trial)
                    dialog.controller.displayLayoutAction("confirm", {
                        id: dialog.controller.trial.id
                    })
            }
        }
    }
    function focusRevert(): void {
        if (visible)
            revert.forceActiveFocus();
    }
    onVisibleChanged: if (visible)
        Qt.callLater(focusRevert)
    Component.onCompleted: if (visible)
        Qt.callLater(focusRevert)
}
