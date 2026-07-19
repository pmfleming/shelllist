import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: button

    required property string label
    property bool danger: false
    property bool available: true
    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 38
    radius: Ui.Theme.cardRadius
    color: danger ? Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.surface, 0.82) : Ui.Theme.surfaceRaised
    border.color: danger ? Ui.Theme.danger : Ui.Theme.border
    opacity: available ? 1 : 0.45

    Text {
        anchors.centerIn: parent
        text: button.label
        color: button.danger ? Ui.Theme.danger : Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }
    MouseArea {
        anchors.fill: parent
        enabled: button.available
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
