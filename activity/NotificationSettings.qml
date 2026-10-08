import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Column {
    id: settings
    required property NotificationState notificationState
    readonly property bool nativeAvailable: notificationState.nativeAvailable
    readonly property var overrides: Object.keys(notificationState.notifications.app_policies || ({})).filter(function (key) {
        const policy = settings.notificationState.appPolicy(key);
        return policy.silent || policy.bypass_dnd || !policy.group_similar;
    })
    width: parent.width
    spacing: Ui.Theme.spacingMd

    Ui.DetailsHeader {
        width: parent.width
        uiScale: 1
        icon: "settings"
        title: qsTr("Notification settings")
        subtitle: qsTr("Applies to all applications")
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
        label: qsTr("Duration")
        icon: "schedule"
        accessibleName: qsTr("Do Not Disturb duration")
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
        uiScale: Ui.Theme.expandedSecondaryActionScale
        objectName: "notificationDndRetry"
        accessKey: "T"
        visible: settings.notificationState.dndError.length > 0
        enabled: !settings.notificationState.dndPending && settings.nativeAvailable
        width: parent.width
        label: qsTr("Retry Do Not Disturb change")
        onClicked: settings.notificationState.retryDnd()
    }
    Ui.ThemeText {
        width: parent.width
        visible: settings.overrides.length > 0
        text: qsTr("App overrides")
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Repeater {
        model: settings.overrides
        Ui.LabeledAction {
            required property string modelData
            width: settings.width
            uiScale: Ui.Theme.expandedSecondaryActionScale
            icon: "refresh"
            label: qsTr("Reset %1 to defaults").arg(modelData.replace(/^(desktop|named):/, ""))
            enabled: settings.nativeAvailable && !settings.notificationState.policyPending[modelData]
            onClicked: settings.notificationState.setAppPolicy(modelData, {silent: false, until_unix_ms: null, group_similar: true, bypass_dnd: false})
        }
    }
    Ui.LabeledAction {
        icon: "delete"
        uiScale: Ui.Theme.expandedSecondaryActionScale
        objectName: "notificationDeleteAll"
        width: parent.width
        label: qsTr("Delete all notifications…")
        accessibleName: qsTr("Delete all notifications with confirmation")
        accessKey: "D"
        enabled: settings.nativeAvailable && !settings.notificationState.deletePreparing && !settings.notificationState.deletePending
        onClicked: settings.notificationState.prepareDelete("", null, qsTr("All applications"))
    }
}
