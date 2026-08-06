import QtQuick
import QtQuick.Layouts

ModalFrame {
    id: dialog

    property string inputText: ""
    property bool inputVisible: true
    property bool password: false
    property bool inputValid: true
    property int inputMaximumLength: 32767
    property int inputMethodHints: Qt.ImhNone
    property int inputHorizontalAlignment: TextInput.AlignLeft
    property bool optionVisible: false
    property bool optionChecked: false
    property string optionLabel: ""
    property bool actionsVisible: false
    property string rejectLabel: "Cancel"
    property string acceptLabel: "Confirm"
    property string acceptTone: "accent"
    property bool acceptEnabled: true
    property bool escapeEnabled: true
    property bool enterEnabled: true
    property string instruction: "Enter continue   •   Esc cancel"
    default property alias promptBody: bodyColumn.data

    signal inputEdited(string text)
    signal accepted
    signal cancelled
    signal optionEdited(bool checked)

    function focusInput() {
        if (inputVisible)
            promptInput.focusInput(true);
    }

    onVisibleChanged: if (visible) Qt.callLater(focusInput)

    Shortcut {
        sequence: "Escape"
        enabled: dialog.visible && dialog.escapeEnabled
        onActivated: dialog.cancelled()
    }
    Shortcut {
        sequence: "Enter"
        enabled: dialog.visible && !dialog.inputVisible && dialog.enterEnabled && dialog.acceptEnabled
        onActivated: dialog.accepted()
    }

    ColumnLayout {
        width: parent.width
        spacing: dialog.bodySpacing

        ColumnLayout {
            id: bodyColumn
            Layout.fillWidth: true
            spacing: dialog.bodySpacing
        }

        TextField {
            id: promptInput

            visible: dialog.inputVisible
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.controlHeight
            text: dialog.inputText
            password: dialog.password
            inputValid: dialog.inputValid
            maximumLength: dialog.inputMaximumLength
            inputMethodHints: dialog.inputMethodHints
            horizontalAlignment: dialog.inputHorizontalAlignment
            fontPixelSize: Theme.fontSizeTitle
            onEdited: function (text) { dialog.inputEdited(text); }
            onAccepted: if (dialog.enterEnabled && dialog.acceptEnabled) dialog.accepted()
        }

        ToggleRow {
            visible: dialog.optionVisible
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 32 : 0
            title: dialog.optionLabel
            checked: dialog.optionChecked
            showSubtitle: false
            onClicked: dialog.optionEdited(!dialog.optionChecked)
        }

        RowLayout {
            visible: dialog.actionsVisible
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            ActionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.controlHeight
                label: dialog.rejectLabel
                onClicked: dialog.cancelled()
            }
            ActionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.controlHeight
                label: dialog.acceptLabel
                tone: dialog.acceptTone
                enabled: dialog.acceptEnabled
                onClicked: dialog.accepted()
            }
        }

        Text {
            visible: dialog.instruction.length > 0
            Layout.fillWidth: true
            text: dialog.instruction
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
