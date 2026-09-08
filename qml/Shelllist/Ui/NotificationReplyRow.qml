import QtQuick

Column {
    id: reply

    required property int notificationId
    required property var submitReply
    required property string draftText
    property bool sending: false
    property bool canReply: true
    property string errorText: ""
    property int controlHeight: 34
    property int buttonWidth: 62
    signal draftEdited(string text)

    width: parent.width
    spacing: Theme.spacingXs

    function send(): void {
        const value = field.text.trim();
        if (value && !sending && canReply)
            submitReply(notificationId, value);
        // Only the acknowledged response in the shared state clears a draft.
    }

    Row {
        width: parent.width
        spacing: Theme.spacingSm
        TextField {
            id: field
            objectName: "notificationReplyInput"
            width: parent.width - sendButton.width - parent.spacing
            height: reply.controlHeight
            placeholder: "Reply…"
            maximumLength: 4096
            text: reply.draftText
            readOnly: reply.sending
            onEdited: function (value) { reply.draftEdited(value); }
            onAccepted: reply.send()
        }
        ActionButton {
            id: sendButton
            width: reply.sending ? Math.max(80, reply.buttonWidth) : reply.buttonWidth
            height: reply.controlHeight
            label: reply.sending ? "Sending…" : "Send"
            enabled: field.text.trim().length > 0 && !reply.sending && reply.canReply
            onClicked: reply.send()
        }
    }
    ThemeText {
        width: parent.width
        visible: text.length > 0
        text: reply.errorText || (!reply.canReply ? "No longer active · draft retained" : "")
        color: Theme.danger
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeCaption
    }
}
