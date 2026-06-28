import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row

    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool interactive: true

    signal clicked

    width: parent ? parent.width : 0
    height: subtitle.length > 0 ? 34 : 26
    spacing: 12

    Column {
        visible: row.subtitle.length > 0
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Text {
            text: row.title
            color: "#e5e7eb"
            font.pixelSize: 14
        }
        Text {
            text: row.subtitle
            color: "#64748b"
            font.pixelSize: 11
        }
    }

    Text {
        visible: row.subtitle.length === 0
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: row.title
        color: "#e5e7eb"
        font.pixelSize: 14
    }

    TogglePill {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
        checked: row.checked
        opacity: row.interactive ? 1.0 : 0.45

        MouseArea {
            anchors.fill: parent
            enabled: row.interactive
            onClicked: row.clicked()
        }
    }
}
