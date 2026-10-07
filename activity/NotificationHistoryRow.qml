pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Column {
    id: row
    required property var record
    required property NotificationController controller
    required property Ui.DetailsNavigation navigation
    readonly property NotificationState notificationState: controller.notificationState
    readonly property var notification: Ui.NotificationPresentation.notificationFor(record)
    readonly property bool active: notificationState.isLive(record)
    readonly property string recordKey: Ui.NotificationPresentation.recordKey(record)
    readonly property var replyStatus: notificationState.replies[recordKey] || ({})
    readonly property string draft: String(notificationState.drafts[recordKey] || "")
    objectName: "notificationHistoryRow-" + notification.id
    width: parent.width
    spacing: Ui.Theme.spacingMd
    function focusReply(): void {
        if (row.visible && replyRow.visible && row.controller.replyKey === row.controller.selectedKey)
            replyRow.focusInput();
    }
    Component.onCompleted: Qt.callLater(focusReply)
    Connections {
        target: row.controller
        function onReplyFocusRequested(): void { Qt.callLater(row.focusReply); }
    }
    NotificationCommands { controller: row.controller; navigation: row.navigation }
    Ui.ThemeText {
        width: parent.width
        text: row.notification.summary || ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeHeading
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
        notificationKey: row.recordKey
        sendAccessKey: row.controller.replyEditorFocused ? "R" : ""
        draftText: row.draft
        sending: row.replyStatus.pending === true
        canReply: row.controller.messageCommandsEnabled && row.active && Ui.NotificationPresentation.replyAction(row.notification) !== null
        errorText: row.replyStatus.error || ""
        onDraftEdited: function (text) { row.notificationState.setDraft(notificationKey, text); }
        onReplyRequested: function (key, text) { row.notificationState.replyNotification(key, text); }
    }
    Ui.ThemeText {
        width: parent.width
        visible: row.controller.replyVisible && row.draft.length > 0 && !row.replyStatus.pending
        text: qsTr("Draft saved · not sent")
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
