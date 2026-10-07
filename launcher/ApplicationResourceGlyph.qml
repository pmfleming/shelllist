pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

// Passive domain glyphs. Names and values belong to the owning static reading.
Item {
    id: icon
    required property string glyph
    property color color: Ui.Theme.mutedText
    property real uiScale: 1
    implicitWidth: Math.round(20 * uiScale)
    implicitHeight: implicitWidth
    Accessible.ignored: true

    Ui.GlyphLabel {
        anchors.fill: parent
        glyph: icon.glyph === "folder_clock" ? "folder" : icon.glyph
        color: icon.color
        font.pixelSize: icon.height
        Accessible.ignored: true
    }
    Rectangle {
        visible: icon.glyph === "folder_clock"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: icon.width * 0.6
        height: width
        radius: width / 2
        color: Ui.Theme.surface
        Ui.GlyphLabel {
            anchors.fill: parent
            glyph: "schedule"
            color: icon.color
            font.pixelSize: parent.height
            Accessible.ignored: true
        }
    }
}
