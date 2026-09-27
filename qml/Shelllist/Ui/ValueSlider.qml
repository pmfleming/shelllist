pragma ComponentBehavior: Bound

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

    implicitWidth: horizontal ? 200 : 44
    implicitHeight: horizontal ? 44 : 200
    padding: 0
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

    background: Item {
        id: track
        x: slider.leftPadding
        y: slider.topPadding
        width: slider.availableWidth
        height: slider.availableHeight
        readonly property real length: slider.horizontal ? width : height
        readonly property real split: 2 + slider.visualPosition * Math.max(0, length - 4)
        readonly property bool fillFromStart: slider.horizontal && !slider.mirrored

        Repeater {
            model: 2
            Rectangle {
                id: section
                required property int index
                readonly property bool leading: index === 0
                readonly property real start: leading ? 0 : track.split + 8
                readonly property real length: Math.max(0, leading ? track.split - 8 : track.length - start)
                readonly property bool filled: leading === track.fillFromStart
                objectName: leading ? "sliderTrackBefore" : "sliderTrackAfter"
                x: slider.horizontal ? start : (track.width - width) / 2
                y: slider.horizontal ? (track.height - height) / 2 : start
                width: slider.horizontal ? length : Math.min(16, track.width)
                height: slider.horizontal ? Math.min(16, track.height) : length
                topLeftRadius: leading ? 8 : 2
                topRightRadius: slider.horizontal ? (leading ? 2 : 8) : (leading ? 8 : 2)
                bottomLeftRadius: slider.horizontal ? (leading ? 8 : 2) : (leading ? 2 : 8)
                bottomRightRadius: leading ? 2 : 8
                color: filled ? (slider.enabled ? Theme.accent : Theme.disabledText) : (slider.enabled ? Theme.selected : Theme.border)

                Rectangle {
                    // Endpoint markers, not a catalogue of discrete tick labels.
                    visible: section.length >= 12
                    width: 4
                    height: 4
                    radius: 2
                    x: slider.horizontal ? (section.leading ? 4 : section.width - 8) : (section.width - width) / 2
                    y: slider.horizontal ? (section.height - height) / 2 : (section.leading ? 4 : section.height - 8)
                    color: section.filled ? Theme.selected : (slider.enabled ? Theme.accent : Theme.disabledText)
                }
            }
        }
    }

    handle: Item {
        // Native Slider owns mapping, dragging, touch and accessible actions.
        // The handle position must agree with its value immediately, including
        // keyboard edits, RTL and vertical orientation. Only thickness springs.
        x: slider.leftPadding + (slider.horizontal ? slider.visualPosition * (slider.availableWidth - width) : (slider.availableWidth - width) / 2)
        y: slider.topPadding + (slider.horizontal ? (slider.availableHeight - height) / 2 : slider.visualPosition * (slider.availableHeight - height))
        width: slider.horizontal ? 4 : Math.min(44, slider.availableWidth)
        height: slider.horizontal ? Math.min(44, slider.availableHeight) : 4

        ExpressiveMotion {
            id: thickness
            target: slider.enabled && (slider.pressed || slider.activeFocus) ? 2 : 4
        }
        Rectangle {
            anchors.centerIn: parent
            width: slider.horizontal ? Math.max(2, Math.min(4, thickness.value)) : parent.width
            height: slider.horizontal ? parent.height : Math.max(2, Math.min(4, thickness.value))
            radius: Math.min(width, height) / 2
            color: slider.enabled ? Theme.accent : Theme.disabledText
        }
    }

    FocusRing {
        active: slider.activeFocus
        cornerRadius: Theme.pressedCornerRadius
    }
}
