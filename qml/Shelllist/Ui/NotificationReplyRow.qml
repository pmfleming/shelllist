import QtQuick

Row {
    id: reply

    required property int notificationId
    required property var submitReply
    property int controlHeight: 34
    property int buttonWidth: 62

    width: parent.width
    spacing: Theme.spacingSm

    function send(): void {
        const value = field.text.trim();
        if (!value)
            return;
        if (submitReply(notificationId, value))
            field.text = "";
    }

    TextField {
        id: field
        width: parent.width - sendButton.width - parent.spacing
        height: reply.controlHeight
        placeholder: "Reply…"
        maximumLength: 4096
        onAccepted: reply.send()
    }

    ActionButton {
        id: sendButton
        width: reply.buttonWidth
        height: reply.controlHeight
        label: "Send"
        enabled: field.text.trim().length > 0
        onClicked: reply.send()
    }
}
