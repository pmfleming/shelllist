import QtQuick

// Decorative only: never participates in pointer, focus or accessibility order.
Rectangle {
    id: badge
    property string text: ""
    implicitWidth: Math.max(20, label.implicitWidth + 12)
    implicitHeight: 20
    radius: 6
    color: Theme.accent
    z: 100
    Accessible.ignored: true
    ThemeText {
        id: label
        anchors.centerIn: parent
        text: badge.text
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightMedium
        color: Theme.accentText
        Accessible.ignored: true
    }
}
