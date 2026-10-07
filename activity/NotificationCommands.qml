pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.CommandGroup {
    id: commands
    required property NotificationController controller
    required property Ui.DetailsNavigation navigation
    visible: controller.messageCommandsEnabled
    enabled: visible
    width: parent.width
    spacing: Ui.Theme.spacingXs
    readonly property var actions: [
        {id: "open", label: qsTr("Open notification"), icon: "󰏌", accessKey: "O", presentation: {group: "primary"}, visible: commands.controller.selectedLive && Ui.NotificationPresentation.defaultAction(commands.controller.selectedNotification) !== null, enabled: !commands.controller.selectedBusy},
        {id: "reply", label: qsTr("Reply"), icon: "󰑚", accessKey: "R", visible: commands.controller.selectedLive && Ui.NotificationPresentation.replyAction(commands.controller.selectedNotification) !== null && !commands.controller.replyEditorFocused, enabled: !commands.controller.selectedBusy},
        {id: "dismiss", label: qsTr("Dismiss notification"), icon: "󰅖", accessKey: "D", visible: commands.controller.selectedLive, enabled: !commands.controller.selectedBusy},
        {id: "snooze", label: qsTr("Snooze for 15 minutes"), icon: "󰒲", accessKey: "Z", visible: commands.controller.selectedLive, enabled: !commands.controller.selectedBusy},
        {id: "copy", label: qsTr("Copy notification text"), icon: "󰆏", accessKey: "C"},
        {id: "actions", label: qsTr("Application actions (Alt+J)"), icon: "󰇙", accessKey: "J", visible: commands.controller.selectedAppActions.length > 0}
    ]
    function trigger(actionId: string): void {
        if (!commands.controller.messageCommandsEnabled) return;
        switch (actionId) {
        case "open": commands.controller.openSelected(); break;
        case "reply": commands.controller.requestReply(); break;
        case "dismiss": if (commands.controller.selectedLive) commands.controller.notificationState.dismissNotification(commands.controller.selectedNotification.id); break;
        case "snooze": if (commands.controller.selectedLive) commands.controller.notificationState.snoozeNotification(commands.controller.selectedNotification.id, 15); break;
        case "copy": commands.controller.copySelected(); break;
        case "actions": commands.navigation.openCommandMenu(); break;
        }
    }
    Ui.NotificationAppIcon { id: identity; visible: false; notification: commands.controller.selectedNotification }
    Ui.DetailsHeader {
        width: parent.width
        uiScale: 1
        compactSecondaryActions: true
        icon: "notifications"
        iconSource: identity.source
        title: commands.controller.selectedNotification.app_name || qsTr("Notification")
        subtitle: new Date(commands.controller.selectedNotification.created_unix_ms || 0).toLocaleString()
        actions: commands.actions.map(action => Object.assign({}, action, {presentation: action.presentation || {group: "toolbar"}}))
        onActionTriggered: function(actionId) { commands.trigger(actionId); }
    }
    Ui.ThemeText {
        width: parent.width
        text: !commands.controller.notificationState.notifications.available ? qsTr("Notifications unavailable · cached message") : commands.controller.selectedLive ? "" : commands.controller.selectedNotification.snoozed_until_unix_ms ? qsTr("Snoozed until %1").arg(new Date(commands.controller.selectedNotification.snoozed_until_unix_ms).toLocaleString()) : qsTr("Closed notification · app actions are no longer available")
        visible: text.length > 0
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: commands.controller.selectedAppActions
        Ui.ActionControl {
            required property var modelData
            objectName: "notificationAction-" + modelData.key
            accessibleName: modelData.label || qsTr("Application action")
            enabled: commands.controller.messageCommandsEnabled && !commands.controller.selectedBusy
            onClicked: commands.controller.invokeAction(modelData.key)
        }
    }
}
