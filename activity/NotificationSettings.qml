import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Column {
    id: settings
    required property NotificationState notificationState
    readonly property bool nativeAvailable: notificationState.notifications.available && notificationState.notifications.backend !== "swaync"
    width: parent.width
    spacing: Ui.Theme.spacingMd

    Ui.ThemeText {
        width: parent.width
        text: qsTr("Notification settings")
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Ui.ThemeText {
        width: parent.width
        text: settings.notificationState.notifications.backend === "swaync" ? qsTr("Notification settings are managed by SwayNC while the fallback backend is enabled.") : qsTr("Do Not Disturb silences popups. Notifications remain in the notification list.")
        wrapMode: Text.WordWrap
    }
    Ui.ToggleRow {
        objectName: "notificationDndSetting"
        width: parent.width
        height: implicitHeight
        title: qsTr("Do Not Disturb")
        checked: settings.notificationState.notifications.dnd === true
        interactive: settings.nativeAvailable && !settings.notificationState.dndPending
        subtitle: settings.notificationState.dndPending ? qsTr("Saving…") : !checked ? qsTr("Off") : settings.notificationState.notifications.dnd_until_unix_ms ? qsTr("Until %1").arg(new Date(settings.notificationState.notifications.dnd_until_unix_ms).toLocaleTimeString()) : qsTr("Until turned off")
        onClicked: settings.notificationState.setDndEnabled(!checked)
    }
    Ui.FormField {
        width: parent.width
        label: qsTr("Do Not Disturb duration")
        Ui.DropDownList {
            objectName: "notificationDndDuration"
            Layout.fillWidth: true
            Accessible.name: qsTr("Do Not Disturb duration")
            value: String(settings.notificationState.dndDurationMinutes)
            interactive: settings.nativeAvailable && !settings.notificationState.dndPending
            options: [
                {
                    value: "30",
                    label: qsTr("30 minutes")
                },
                {
                    value: "60",
                    label: qsTr("1 hour")
                },
                {
                    value: "0",
                    label: qsTr("Until turned off")
                }
            ]
            onSelected: function (value) {
                settings.notificationState.setDndDuration(Number(value));
            }
        }
    }
    Ui.ThemeText {
        width: parent.width
        text: settings.notificationState.dndError
        visible: text.length > 0
        color: Ui.Theme.danger
        wrapMode: Text.WordWrap
    }
    Ui.LabeledAction {
        icon: "refresh"
        objectName: "notificationDndRetry"
        accessKey: "T"
        visible: settings.notificationState.dndError.length > 0
        enabled: !settings.notificationState.dndPending && settings.nativeAvailable
        width: parent.width
        label: qsTr("Retry Do Not Disturb change")
        onClicked: settings.notificationState.retryDnd()
    }
    Ui.LabeledAction {
        icon: "clear_all"
        objectName: "notificationClearAll"
        visible: settings.notificationState.activeNotifications.length > 0
        width: parent.width
        label: qsTr("Dismiss all live notifications")
        accessibleName: qsTr("Dismiss all live notifications; retain history")
        onClicked: settings.notificationState.clearNotifications()
    }
}
