import QtQuick
import QtQuick.Controls as Controls

Controls.Slider {
    id: slider

    signal edited(real value)

    implicitHeight: Theme.compactControlHeight
    live: true
    snapMode: Controls.Slider.SnapAlways
    activeFocusOnTab: enabled
    onMoved: edited(value)

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 6
        radius: height / 2
        color: Theme.border

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: slider.enabled ? Theme.accent : Theme.disabledText
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: 20
        height: 20
        radius: width / 2
        color: slider.enabled ? Theme.accent : Theme.disabledText
        border.width: slider.activeFocus ? 3 : 2
        border.color: slider.activeFocus ? Theme.text : Theme.window

        Behavior on x {
            enabled: !slider.pressed && !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Theme.easingGentle
            }
        }
    }
}
