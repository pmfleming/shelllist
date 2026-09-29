pragma ComponentBehavior: Bound

import QtQuick

Row {
    id: controls

    required property bool showReply
    readonly property bool activeFocusInside: replyButton.activeFocus || snoozeButton.activeFocus || dismissButton.activeFocus
    readonly property bool focusInside: replyButton.highlighted || snoozeButton.highlighted || dismissButton.highlighted

    signal replyRequested
    signal snoozeRequested
    signal dismissRequested

    spacing: 2

    component HeaderAction: FlatIconButton {
        width: 32
        height: 32
        toolTip: accessibleName
    }

    HeaderAction {
        id: replyButton
        objectName: "notificationQuickReply"
        visible: controls.showReply
        icon: "󰑚"
        accessibleName: "Reply"
        onClicked: controls.replyRequested()
    }
    HeaderAction {
        id: snoozeButton
        objectName: "notificationQuickSnooze"
        icon: "󰒲"
        accessibleName: "Snooze for 15 minutes"
        onClicked: controls.snoozeRequested()
    }
    HeaderAction {
        id: dismissButton
        objectName: "notificationQuickDismiss"
        icon: "󰅖"
        accessibleName: "Dismiss"
        onClicked: controls.dismissRequested()
    }
}
