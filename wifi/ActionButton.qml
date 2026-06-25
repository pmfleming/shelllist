import QtQuick

Rectangle {
    id: control

    property string label: ""
    property color backgroundColor: "#111827"
    property color borderColor: "#233247"
    property color labelColor: "#cbd5e1"

    signal clicked

    height: 42
    radius: 8
    color: backgroundColor
    border.color: borderColor
    opacity: enabled ? 1.0 : 0.45

    Text {
        anchors.centerIn: parent
        text: control.label
        color: control.labelColor
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        onClicked: control.clicked()
    }
}
