import QtQuick
import QtQuick.Layouts
import "WifiPresentation.js" as Presentation
import "."

RowLayout {
    id: row

    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property bool checked: false
    property bool interactive: true
    property bool showSubtitle: true

    signal clicked

    width: parent ? parent.width : 0
    height: showSubtitle && subtitle.length > 0 ? 40 : 30
    spacing: 12

    Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        Text {
            text: Presentation.highlightHotkey(row.title, row.hotkey)
            textFormat: Text.RichText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        Text {
            visible: row.showSubtitle && row.subtitle.length > 0
            text: row.subtitle
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    TogglePill {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        checked: row.checked
        opacity: row.interactive ? 1.0 : 0.45

        MouseArea {
            anchors.fill: parent
            enabled: row.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
