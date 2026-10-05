pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PointerActionControl {
    id: row
    required property string title
    property string subtitle: ""
    property string icon: "settings"
    implicitHeight: Math.max(64, labels.implicitHeight + 2 * Ui.Theme.spacingSm)
    Layout.minimumHeight: implicitHeight
    radius: Ui.Theme.controlRadius
    color: highlighted || hovered ? Ui.Theme.hover : "transparent"
    accessibleName: title
    Accessible.description: subtitle

    RowLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingSm
        spacing: Ui.Theme.spacingMd
        Ui.GlyphLabel {
            glyph: row.icon
            color: Ui.Theme.accent
            font.pixelSize: Ui.Theme.iconSizeLarge
        }
        Column {
            id: labels
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingXs
            Ui.ThemeText {
                width: parent.width
                text: row.title
                font.pixelSize: Ui.Theme.fontSizeHeading
                wrapMode: Text.Wrap
            }
            Ui.ThemeText {
                width: parent.width
                visible: row.subtitle.length > 0
                text: row.subtitle
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        Ui.GlyphLabel {
            glyph: "chevron_right"
            color: Ui.Theme.mutedText
        }
    }
}
