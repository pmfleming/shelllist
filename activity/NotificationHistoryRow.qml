pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: row
    required property var record
    required property NotificationController controller
    readonly property NotificationState notificationState: controller.notificationState
    readonly property var notification: Ui.NotificationPresentation.notificationFor(record)
    readonly property bool active: notificationState.isLive(record)
    readonly property var replyStatus: notificationState.replies[notification.id] || ({})
    readonly property string draft: String(notificationState.drafts[notification.id] || "")

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
        Ui.NotificationAppIcon { notification: row.notification }
        Ui.ThemeText {
            width: parent.width
            text: [row.notification.app_name, Ui.NotificationPresentation.timeLabel(row.notification.created_unix_ms, row.controller.nowMs)].filter(part => !!part).join(" · ")
            color: Ui.Theme.mutedText
            wrapMode: Text.WordWrap
        }
        Ui.ThemeText {
            width: parent.width
            text: row.notification.summary || row.notification.app_name || qsTr("Notification")
            wrapMode: Text.Wrap
            font.weight: Ui.Theme.fontWeightDemiBold
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
            notificationId: Number(row.notification.id || 0)
            draftText: row.draft
            sending: row.replyStatus.pending === true
            canReply: row.active && Ui.NotificationPresentation.replyAction(row.notification) !== null
            errorText: row.replyStatus.error || ""
            onDraftEdited: function (text) { row.notificationState.setDraft(notificationId, text); }
            submitReply: function (id, text) { return row.notificationState.replyNotification(id, text); }
        }
    }
}
