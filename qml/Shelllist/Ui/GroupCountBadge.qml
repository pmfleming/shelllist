import QtQuick

Rectangle {
    id: badge
    required property int count

    visible: count > 1
    width: 18
    height: 18
    radius: width / 2
    color: Theme.accent
    border.color: Theme.surfaceRaised
    border.width: 2

    ThemeText {
        anchors.centerIn: parent
        text: badge.count > 9 ? "9+" : String(badge.count)
        color: Theme.accentText
        font.pixelSize: 9
        font.weight: Theme.fontWeightBold
    }
}
