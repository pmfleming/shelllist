import QtQuick
import QtQuick.Layouts
import "UiText.js" as UiText

Rectangle {
    id: row

    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property string tone: "normal"
    property bool checked: false
    property bool interactive: true
    property bool showSubtitle: true

    signal clicked

    width: parent ? parent.width : 0
    implicitHeight: showSubtitle && subtitle.length > 0 ? 40 : 30
    radius: Theme.controlRadius
    color: area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : "transparent")
    border.color: activeFocus ? Theme.strongBorder : "transparent"
    border.width: 1
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled && interactive

    Keys.onReturnPressed: function (event) { row.clicked(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { row.clicked(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { row.clicked(); event.accepted = true; }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(Theme.spacingXs / 2)

            Text {
                text: UiText.highlightHotkey(row.title, row.hotkey)
                textFormat: Text.RichText
                color: row.tone === "danger" ? Theme.danger
                    : (row.tone === "active" ? Theme.active
                    : (row.tone === "warning" ? Theme.warning : Theme.text))
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
            }

            Text {
                visible: row.showSubtitle && row.subtitle.length > 0
                text: row.subtitle
                color: Theme.subtleText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
                elide: Text.ElideRight
            }
        }

        TogglePill {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            checked: row.checked
            checkedColor: row.tone === "danger" ? Theme.danger
                : (row.tone === "active" ? Theme.active
                : (row.tone === "warning" ? Theme.warning : Theme.accent))
        }
    }

    ControlPointerArea { id: area; focusTarget: row; enabled: row.enabled && row.interactive; onClicked: row.clicked() }
}
