pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Column {
    id: commands
    required property NotificationController controller
    required property Ui.DetailsNavigation navigation
    visible: controller.hasSelection && !controller.settingsOpen
    width: parent.width
    spacing: Ui.Theme.spacingXs

    Ui.ActionToolbar {
        width: parent.width
        alignRight: false
        tabFocusEnabled: false
        actions: [
            {id: "open", label: qsTr("Open notification"), icon: "󰏌", accessKey: "O", visible: commands.controller.selectedLive && Ui.NotificationPresentation.defaultAction(commands.controller.selectedNotification) !== null, enabled: !commands.controller.selectedBusy},
            {id: "reply", label: qsTr("Reply"), icon: "󰑚", accessKey: "R", visible: commands.controller.selectedLive && Ui.NotificationPresentation.replyAction(commands.controller.selectedNotification) !== null && !commands.controller.replyVisible, enabled: !commands.controller.selectedBusy},
            {id: "dismiss", label: qsTr("Dismiss notification"), icon: "󰅖", accessKey: "D", visible: commands.controller.selectedLive, enabled: !commands.controller.selectedBusy},
            {id: "snooze", label: qsTr("Snooze for 15 minutes"), icon: "󰒲", accessKey: "Z", visible: commands.controller.selectedLive, enabled: !commands.controller.selectedBusy},
            {id: "copy", label: qsTr("Copy notification text"), icon: "󰆏", accessKey: "C"},
            {id: "actions", label: qsTr("Application actions (Alt+J)"), icon: "󰇙", accessKey: "J", visible: commands.controller.selectedAppActions.length > 0}
        ]
        onTriggered: function (actionId) {
            switch (actionId) {
            case "open": commands.controller.primarySelected(); break;
            case "reply": commands.controller.requestReply(); break;
            case "dismiss": commands.controller.notificationState.dismissNotification(commands.controller.selectedNotification.id); break;
            case "snooze": commands.controller.notificationState.snoozeNotification(commands.controller.selectedNotification.id, 15); break;
            case "copy": commands.controller.copySelected(); break;
            case "actions": commands.navigation.openCommandMenu(); break;
            }
        }
    }
    Ui.ThemeText {
        width: parent.width
        text: commands.controller.selectedLive ? qsTr("Hold Alt for commands · Alt+J for app actions") : qsTr("Closed notification · app actions are no longer available")
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
