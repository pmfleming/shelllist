import QtQuick
import QtQuick.Layouts
import "UiText.js" as UiText

ActionControl {
    id: row

    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property string tone: "normal"
    property bool checked: false
    property bool showSubtitle: true
    property bool wrapTitle: false

    width: parent ? parent.width : 0
    implicitHeight: Math.max(56, labels.implicitHeight + 2 * Theme.spacingSm)
    Layout.minimumHeight: implicitHeight
    radius: Theme.controlRadius
    color: "transparent"
    focusSurface: toggleFocus
    border.width: 0
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    accessibleName: subtitle.length > 0 ? title + ". " + subtitle : title
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onToggleAction: activate()
    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd

        Column {
            id: labels
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(Theme.spacingXs / 2)

            ThemeText {
                width: labels.width
                elide: row.wrapTitle ? Text.ElideNone : Text.ElideRight
                wrapMode: row.wrapTitle ? Text.WordWrap : Text.NoWrap
                text: UiText.highlightHotkey(row.title, row.hotkey)
                textFormat: Text.RichText
                color: row.tone === "danger" ? Theme.danger : (row.tone === "active" ? Theme.active : (row.tone === "warning" ? Theme.warning : Theme.text))
                font.pixelSize: Theme.fontSizeHeading
            }

            ThemeText {
                objectName: "toggleSubtitle"
                width: labels.width
                visible: row.showSubtitle && row.subtitle.length > 0
                text: row.subtitle
                color: Theme.subtleText
                font.pixelSize: Theme.fontSizeLabel
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: toggleFocus
            Layout.preferredWidth: 64
            Layout.preferredHeight: Theme.controlHeight
            radius: height / 2
            color: area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : "transparent")
            TogglePill {
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                checked: row.checked
                pressed: row.enabled && row.interactive && (area.pressed || row.keyboardPressed)
                checkedColor: row.tone === "danger" ? Theme.danger : (row.tone === "active" ? Theme.active : (row.tone === "warning" ? Theme.warning : Theme.accent))
                handleColor: !checked ? Theme.controlBorder : (row.tone === "danger" ? Theme.dangerText : (row.tone === "active" ? Theme.activeText : (row.tone === "warning" ? Theme.warningText : Theme.accentText)))
            }
        }
    }

    ControlPointerArea {
        id: area
        focusTarget: row
        enabled: row.enabled && row.interactive
        onClicked: row.activate()
    }
}
