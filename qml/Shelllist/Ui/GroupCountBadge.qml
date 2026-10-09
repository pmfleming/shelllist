import QtQuick

Rectangle {
    id: badge
    required property int count

    visible: count > 1
    width: Theme.metadataSize + 10
    height: width
    radius: width / 2
    color: Theme.accent
    border.color: Theme.surfaceRaised
    border.width: 2
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Grouped items: %1").arg(count)

    ThemeText {
        anchors.centerIn: parent
        text: badge.count > 9 ? "9+" : String(badge.count)
        color: Theme.accentText
        font.pixelSize: Theme.metadataSize
        Accessible.ignored: true
        font.weight: Theme.fontWeightBold
    }
}
