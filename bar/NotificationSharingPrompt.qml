pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: prompt
    required property BarController controller
    readonly property var store: controller?.notificationState || null
    objectName: "notificationSharingPrompt"
    title: qsTr("Screen sharing detected")
    Ui.ThemeText {
        Layout.fillWidth: true
        text: prompt.controller?.notifications.sharing?.prompt
            ? qsTr("Popups are paused. Snooze notifications for:")
            : qsTr("Snooze notifications for:")
        wrapMode: Text.Wrap
    }
    Repeater {
        model: [{minutes: 15, label: qsTr("15 minutes")}, {minutes: 60, label: qsTr("1 hour")}, {minutes: 0, label: qsTr("Until sharing ends")}]
        Ui.LabeledAction {
            required property var modelData
            objectName: "notificationSharingSnooze" + modelData.minutes
            Layout.fillWidth: true
            icon: "snooze"
            label: modelData.label
            enabled: !!prompt.store && prompt.store.nativeAvailable && !prompt.store.sharingPending
            onClicked: prompt.store.snoozeSharing(modelData.minutes)
        }
    }
    Ui.FeedbackSource {
        text: prompt.store?.sharingError || ""
        summaryText: qsTr("Notification snooze failed")
        tone: "error"
    }
    Ui.FeedbackSlot {
        Layout.fillWidth: true
        scope: prompt
    }
    Connections {
        target: prompt.store
        function onSharingPendingChanged(): void {
            if (prompt.store && prompt.controller && !prompt.store.sharingPending && !prompt.store.sharingError)
                prompt.controller.sharingPromptOpen = false;
        }
    }
}
