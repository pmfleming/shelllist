import QtQuick

// A presentation contribution, never a layout item, editor or request owner.
// The surface's fixed FeedbackSlot reads only contributions on visible routes.
Item {
    property bool active: true
    property string text: ""
    property string summaryText: text
    property string briefText: qsTr("Check status")
    property string tone: "info"
    property int priority: tone === "error" ? 30 : tone === "warning" ? 20 : 10
    visible: false
    width: 0
    height: 0
    implicitWidth: 0
    implicitHeight: 0
    Accessible.ignored: true
}
