import QtQuick

// Passive spacing between native ListView sections; never a result or Tab stop.
Item {
    implicitHeight: Theme.spacingMd
    clip: true
    Accessible.ignored: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        height: 1
        color: Theme.border
        Accessible.ignored: true
    }
}
