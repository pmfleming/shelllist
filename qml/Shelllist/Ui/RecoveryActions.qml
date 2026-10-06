import QtQuick.Layouts

// Presentation only: each domain retains its own draft, acknowledgement and
// retry/discard guards. Named controls keep their command and test identities.
RowLayout {
    id: row
    readonly property alias retryAction: retry
    readonly property alias discardAction: discard
    signal retryRequested
    signal discardRequested

    LabeledAction {
        id: retry
        Layout.fillWidth: true
        icon: "refresh"
        label: qsTr("Retry save")
        accessKey: "R"
        onClicked: row.retryRequested()
    }
    LabeledAction {
        id: discard
        Layout.fillWidth: true
        icon: "undo"
        label: qsTr("Discard draft")
        accessKey: "X"
        onClicked: row.discardRequested()
    }
}
