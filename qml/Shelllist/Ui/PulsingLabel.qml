import QtQuick

Text {
    id: label

    property bool pulseEnabled: !Theme.noAnimations

    onTextChanged: if (pulseEnabled) pulse.restart()

    SequentialAnimation {
        id: pulse

        NumberAnimation {
            target: label
            property: "opacity"
            to: 0.32
            duration: Math.round(Theme.animationFast * 0.35)
        }
        NumberAnimation {
            target: label
            property: "opacity"
            to: 1
            duration: Math.round(Theme.animationFast * 0.65)
        }
    }
}
