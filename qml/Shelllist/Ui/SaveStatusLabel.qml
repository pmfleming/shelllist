import QtQuick

FeedbackSource {
    required property bool valid
    required property string error
    required property bool saving
    tone: !valid || error.length > 0 ? "error" : "info"
    summaryText: !valid ? qsTr("Invalid settings") : error.length ? qsTr("Settings not saved") : saving ? qsTr("Saving…") : text
}
