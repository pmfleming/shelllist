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
    icon: "monitor"
    actions: [
        {id: "confirm", label: qsTr("Keep layout"), icon: "check", enabled: controller.backend.ready && !controller.actionInFlight && !controller.stale && controller.secondsLeft > 0, presentation: {group: "primary"}},
        {id: "revert", label: qsTr("Revert layout"), icon: "undo", enabled: controller.backend.ready && !controller.actionInFlight, presentation: {group: "toolbar"}}
    ]
    onActionTriggered: function(actionId) {
        if (controller.trial) controller.displayLayoutAction(actionId, {id: controller.trial.id});
    }
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
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Keep this layout with the check button, or undo to revert now. Without confirmation the previous layout is restored automatically.")
            wrapMode: Text.Wrap
        }
    }
    function focusRevert(): void {
        if (visible)
            focusAction("revert");
    }
    onVisibleChanged: if (visible)
        Qt.callLater(focusRevert)
    Component.onCompleted: if (visible)
        Qt.callLater(focusRevert)
}
