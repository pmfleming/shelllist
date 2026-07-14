import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
import "."

RowLayout {
    id: row

    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property bool checked: false
    property bool interactive: true

    signal clicked

    width: parent ? parent.width : 0
    height: subtitle.length > 0 ? 34 : 26
    spacing: 12

    Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Text {
            text: Wifi.highlightHotkey(row.title, row.hotkey)
            textFormat: Text.RichText
            color: Theme.text
            font.pixelSize: 14
        }
        Text {
            text: row.subtitle
            visible: row.subtitle.length > 0
            color: Theme.subtleText
            font.pixelSize: 11
        }
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
