pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

Controls.ScrollBar {
    id: scrollBar
    padding: 0
    width: Theme.spacingSm
    minimumSize: 0.04
    focusPolicy: Qt.NoFocus
    Accessible.name: qsTr("Scroll contents")
    background: null
    contentItem: Rectangle {
        implicitWidth: Theme.spacingSm
        radius: width / 2
        color: scrollBar.pressed ? Theme.accent : Theme.mutedText
    }
}
