import QtQuick

// Passive, non-command shape: a lock is not permission to unlock a setting.
Rectangle {
    id: badge
    property bool readOnly: false
    property bool unavailable: false
    visible: readOnly || unavailable
    implicitWidth: Theme.formActionSize
    implicitHeight: Theme.formActionSize
    radius: 8
    color: unavailable ? Theme.surfaceRaised : Theme.selected
    Accessible.ignored: true
    GlyphLabel {
        objectName: "fieldStateGlyph"
        anchors.centerIn: parent
        glyph: badge.unavailable ? "block" : "lock"
        font.pixelSize: Theme.formIconSize
        color: badge.unavailable ? Theme.mutedText : Theme.selectedText
        Accessible.ignored: true
    }
}
