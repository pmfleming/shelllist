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
    property bool wrapTitle: true
    property bool compact: false
    property var icons: []

    width: parent ? parent.width : 0
    implicitHeight: Math.max(compact ? Theme.formHeight : 56, labels.implicitHeight + 2 * Theme.spacingSm)
    Layout.minimumHeight: implicitHeight
    radius: Theme.controlRadius
    color: "transparent"
    focusSurface: toggleFocus
    border.width: 0
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
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(Theme.spacingXs / 2)

            ThemeText {
                width: labels.width
                elide: row.wrapTitle ? Text.ElideNone : Text.ElideRight
                wrapMode: row.wrapTitle ? Text.WordWrap : Text.NoWrap
                text: UiText.highlightHotkey(row.title, row.hotkey)
                textFormat: Text.RichText
                color: row.tone === "danger" ? Theme.danger : (row.tone === "active" ? Theme.active : (row.tone === "warning" ? Theme.warning : Theme.mutedText))
                font.pixelSize: Theme.fieldNameSize
                font.weight: Theme.fieldNameWeight
            }

            ThemeText {
                objectName: "toggleSubtitle"
                width: labels.width
                visible: row.showSubtitle && row.subtitle.length > 0
                text: row.subtitle
                color: Theme.subtleText
                font.pixelSize: Theme.statusTextSize
                wrapMode: Text.Wrap
            }
        }

        Rectangle {
            id: toggleFocus
            Layout.preferredWidth: 64
            Layout.minimumWidth: 64
            Layout.preferredHeight: Theme.controlHeight
            radius: height / 2
            color: row.pointerPressed ? Theme.pressed : (row.hovered ? Theme.hover : "transparent")
            TogglePill {
                anchors.centerIn: parent
                // Compact changes row spacing, never the switch target/track.
                width: implicitWidth
                height: implicitHeight
                opacity: row.enabled && row.interactive ? 1.0 : Theme.disabledOpacity
                checked: row.checked
                pressed: row.pressed
                checkedColor: row.tone === "danger" ? Theme.danger : (row.tone === "active" ? Theme.active : (row.tone === "warning" ? Theme.warning : Theme.accent))
                handleColor: !checked ? Theme.controlBorder : (row.tone === "danger" ? Theme.dangerText : (row.tone === "active" ? Theme.activeText : (row.tone === "warning" ? Theme.warningText : Theme.accentText)))
            }
        }
    }
}
