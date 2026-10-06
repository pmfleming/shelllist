import QtQuick
import QtQuick.Layouts

FormField {
    id: reply

    required property string notificationKey
    required property string draftText
    property bool sending: false
    property bool canReply: true
    errorText: ""
    label: qsTr("Reply")
    editor: field
    statusText: sending ? qsTr("Sending…") : (!canReply ? qsTr("No longer active") : "")
    property int controlHeight: Theme.formHeight
    property string sendAccessKey: "R"
    property int buttonWidth: controlHeight
    signal draftEdited(string text)
    signal replyRequested(string key, string text)

    width: parent.width

    function focusInput(): void {
        field.focusInput(false);
    }

    function send(): void {
        const value = field.text.trim();
        if (!value || sending || !canReply)
            return;
        // Sending is an explicit save boundary too. Retire the local editor
        // transaction so the eventual acknowledgement can clear its binding.
        const navigation = field.editSession.navigation;
        if (navigation && navigation.editorTarget === field)
            navigation.saveEditor();
        replyRequested(notificationKey, value);
        // Only the acknowledged response in the shared state clears a draft.
    }

    Row {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        TextField {
            id: field
            objectName: "notificationReplyInput"
            focusKey: "notification::" + reply.notificationKey + "::reply"
            width: parent.width - sendButton.width - parent.spacing
            height: reply.controlHeight
            placeholder: qsTr("Write a reply")
            errorText: reply.errorText
            maximumLength: 4096
            text: reply.draftText
            readOnly: reply.sending
            onEdited: function (value) {
                reply.draftEdited(value);
            }
            onAccepted: reply.send()
        }
        ActionButton {
            id: sendButton
            accessKey: reply.sendAccessKey
            commandScope: reply
            width: reply.buttonWidth
            height: reply.controlHeight
            tone: "accent"
            sizeRole: "primary"
            icon: reply.sending ? "󰔟" : "󰒊"
            accessibleName: reply.sending ? "Sending reply" : "Send reply"
            toolTip: accessibleName
            enabled: field.text.trim().length > 0 && !reply.sending && reply.canReply
            onClicked: reply.send()
        }
    }
}
