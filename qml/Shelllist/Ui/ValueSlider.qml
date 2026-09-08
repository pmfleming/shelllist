import QtQuick
import QtQuick.Controls as Controls

Controls.Slider {
    id: slider

    signal edited(real value)
    signal editingFinished

    function moveToBoundary(boundary: real): void {
        if (!enabled || value === boundary)
            return;
        value = boundary;
        edited(value);
        editingFinished();
    }

    implicitHeight: Theme.compactControlHeight
    live: true
    snapMode: Controls.Slider.SnapAlways
    activeFocusOnTab: enabled
    onMoved: edited(value)
    onPressedChanged: if (!pressed)
        editingFinished()
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            moveToBoundary(event.key === Qt.Key_Home ? from : to);
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

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
                duration: Theme.animationInteractive
                easing.type: Theme.easingResponsive
            }
        }
    }
}
