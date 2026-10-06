pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: row
    required property var record
    required property NotificationController controller
    property Item commandItem: null
    readonly property alias headerHost: headerHost
    readonly property NotificationState notificationState: controller.notificationState
    readonly property var notification: Ui.NotificationPresentation.notificationFor(record)
    readonly property bool active: notificationState.isLive(record)
    readonly property string recordKey: Ui.NotificationPresentation.recordKey(record)
    readonly property var replyStatus: notificationState.replies[recordKey] || ({})
    readonly property string draft: String(notificationState.drafts[recordKey] || "")

    objectName: "notificationHistoryRow-" + notification.id
    width: parent.width
    implicitHeight: body.implicitHeight + Ui.Theme.spacingMd * 2
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surfaceRaised
    border.color: Ui.Theme.border

    function focusReply(): void {
        if (row.visible && replyRow.visible && row.controller.replyKey === row.controller.selectedKey)
            replyRow.focusInput();
    }
    Component.onCompleted: Qt.callLater(focusReply)
    Connections {
        target: row.controller
        function onReplyFocusRequested(): void { Qt.callLater(row.focusReply); }
    }

    Column {
        id: body
        x: Ui.Theme.spacingMd
        y: Ui.Theme.spacingMd
        width: parent.width - Ui.Theme.spacingMd * 2
        spacing: Ui.Theme.spacingMd
        Item {
            id: headerHost
            width: parent.width
            height: row.commandItem ? row.commandItem.implicitHeight : 0
        }
        Ui.ThemeText {
            objectName: "notificationBody"
            width: parent.width
            visible: text.length > 0
            text: row.notification.body || ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        Ui.NotificationReplyRow {
            id: replyRow
            visible: row.controller.replyVisible
            notificationKey: row.recordKey
            sendAccessKey: row.controller.replyEditorFocused ? "R" : ""
            draftText: row.draft
            sending: row.replyStatus.pending === true
            canReply: row.active && Ui.NotificationPresentation.replyAction(row.notification) !== null
            errorText: row.replyStatus.error || ""
            onDraftEdited: function (text) { row.notificationState.setDraft(notificationKey, text); }
            onReplyRequested: function (key, text) { row.notificationState.replyNotification(key, text); }
        }
    }
}
