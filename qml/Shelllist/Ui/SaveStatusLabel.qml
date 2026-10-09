import QtQuick

InlineStatus {
    required property bool valid
    required property string error
    required property bool saving

    tone: !valid || error.length > 0 ? "error" : "info"
}
