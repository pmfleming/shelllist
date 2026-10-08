import QtQuick
import QtQuick.Layouts
import "UiText.js" as UiText

PointerActionControl {
    id: row

    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property string tone: "normal"
    property bool checked: false
    property bool showSubtitle: true
    property bool wrapTitle: false
    property bool compact: false
    property var icons: []

    width: parent ? parent.width : 0
    implicitHeight: Math.max(compact ? Theme.formHeight : 56, labels.implicitHeight + 2 * Theme.spacingSm)
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

        Repeater {
            model: row.icons
            delegate: GlyphLabel {
                required property string modelData
                glyph: modelData
                Layout.preferredWidth: Theme.iconSize
                font.pixelSize: Theme.iconSize
                Accessible.ignored: true
            }
        }

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
                font.pixelSize: row.compact ? Theme.fontSizeLabel : Theme.fontSizeHeading
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
            Layout.preferredWidth: row.compact ? 48 : 64
            Layout.preferredHeight: row.compact ? 32 : Theme.controlHeight
            radius: height / 2
            color: row.pointerPressed ? Theme.pressed : (row.hovered ? Theme.hover : "transparent")
            TogglePill {
                anchors.centerIn: parent
                width: row.compact ? 42 : implicitWidth
                height: row.compact ? 26 : implicitHeight
                checked: row.checked
                pressed: row.pressed
                checkedColor: row.tone === "danger" ? Theme.danger : (row.tone === "active" ? Theme.active : (row.tone === "warning" ? Theme.warning : Theme.accent))
                handleColor: !checked ? Theme.controlBorder : (row.tone === "danger" ? Theme.dangerText : (row.tone === "active" ? Theme.activeText : (row.tone === "warning" ? Theme.warningText : Theme.accentText)))
            }
        }
    }
}
