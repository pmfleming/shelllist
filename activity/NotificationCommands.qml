pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.CommandGroup {
    id: commands
    required property NotificationController controller
    required property Ui.DetailsNavigation navigation
    property Item detailHost: null
    required property Item listHost
    parent: controller.detailsOpen && detailHost ? detailHost : listHost
    visible: controller.hasSelection && !controller.settingsOpen
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
        switch (actionId) {
        case "open": commands.controller.primarySelected(); break;
        case "reply": commands.controller.requestReply(); break;
        case "dismiss": commands.controller.notificationState.dismissNotification(commands.controller.selectedNotification.id); break;
        case "snooze": commands.controller.notificationState.snoozeNotification(commands.controller.selectedNotification.id, 15); break;
        case "copy": commands.controller.copySelected(); break;
        case "actions": commands.navigation.openCommandMenu(); break;
        }
    }
    Ui.NotificationAppIcon {
        id: identity
        visible: false
        notification: commands.controller.selectedNotification
    }
    Ui.DetailsHeader {
        visible: commands.controller.detailsOpen && commands.detailHost !== null
        width: parent.width
        uiScale: 1
        compactSecondaryActions: true
        icon: "notifications"
        iconSource: identity.source
        title: commands.controller.selectedNotification.summary || commands.controller.selectedNotification.app_name || qsTr("Notification")
        subtitle: [commands.controller.selectedNotification.app_name, Ui.NotificationPresentation.timeLabel(commands.controller.selectedNotification.created_unix_ms, commands.controller.nowMs)].filter(Boolean).join(" · ")
        actions: commands.actions.map(action => Object.assign({}, action, {presentation: action.presentation || {group: "toolbar"}}))
        onActionTriggered: function(actionId) { commands.trigger(actionId); }
    }
    Ui.ActionToolbar {
        visible: !commands.controller.detailsOpen || commands.detailHost === null
        width: parent.width
        tabFocusEnabled: false
        includeAllGroups: true
        actions: commands.actions
        onTriggered: function(actionId) { commands.trigger(actionId); }
    }
    Ui.ThemeText {
        width: parent.width
        text: !commands.controller.notificationState.notifications.available ? qsTr("Notifications unavailable · cached message") : commands.controller.selectedLive ? qsTr("Hold Alt for commands · Alt+J for app actions") : commands.controller.selectedNotification.snoozed_until_unix_ms ? qsTr("Snoozed notification") : qsTr("Closed notification · app actions are no longer available")
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
        wrapMode: Text.WordWrap
    }
    // Presentation-free ActionControls participate in the shared Alt+J menu,
    // not layout or Tab traversal. App-supplied keys/labels stay opaque.
    Repeater {
        model: commands.controller.selectedAppActions
        Ui.ActionControl {
            required property var modelData
            objectName: "notificationAction-" + modelData.key
            accessibleName: modelData.label || qsTr("Application action")
            enabled: !commands.controller.selectedBusy
            onClicked: commands.controller.invokeAction(modelData.key)
        }
    }
}
