pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Passive telemetry/caveat: one accessible description, no new field stop.
RowLayout {
    id: reading
    property var icons: []
    property string text: ""
    property string description: ""
    property color color: Ui.Theme.mutedText
    property int pixelSize: Ui.Theme.fontSizeLabel
    spacing: Ui.Theme.spacingSm
    Accessible.role: Accessible.StaticText
    Accessible.name: description

    Repeater {
        model: reading.icons
        delegate: Ui.GlyphLabel {
            required property string modelData
            glyph: modelData
            color: reading.color
            font.pixelSize: Ui.Theme.iconSize
            Accessible.ignored: true
        }
    }
    Ui.ThemeText {
        visible: reading.text.length > 0
        text: reading.text
        color: reading.color
        font.pixelSize: reading.pixelSize
        Accessible.ignored: true
    }
    Item { Layout.fillWidth: true }
}
