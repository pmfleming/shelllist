import QtQuick

FieldLabel {
    required property bool valid
    required property string error
    required property bool saving

    color: !valid || error.length > 0 ? Theme.danger : (saving ? Theme.active : Theme.mutedText)
}
