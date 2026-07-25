pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: control

    property var options: []
    property string value: ""
    property bool interactive: true

    signal selected(string value)

    readonly property int contentPadding: 3
    readonly property real segmentWidth: options.length > 0
        ? (width - 2 * contentPadding) / options.length
        : 0
    readonly property int currentIndex: {
        for (let index = 0; index < options.length; ++index)
            if (options[index].value === value)
                return index;
        return -1;
    }

    implicitHeight: Theme.compactControlHeight
    radius: Theme.controlRadius
    color: Theme.input
    border.color: activeFocus ? Theme.strongBorder : Theme.border
    border.width: 1
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    clip: true
    activeFocusOnTab: interactive

    function optionEnabled(index) {
        return index >= 0 && index < options.length && options[index].enabled !== false;
    }

    function choose(index) {
        if (!interactive || !optionEnabled(index))
            return;
        const nextValue = options[index].value;
        if (nextValue !== value)
            selected(nextValue);
    }

    function nextEnabledIndex(index, delta, remaining) {
        if (remaining === 0 || index < 0 || index >= options.length)
            return -1;
        return optionEnabled(index) ? index : nextEnabledIndex(index + delta, delta, remaining - 1);
    }

    function move(delta) {
        if (options.length === 0)
            return;
        const initial = currentIndex >= 0 ? currentIndex : (delta > 0 ? -1 : options.length);
        const next = nextEnabledIndex(initial + delta, delta, options.length);
        if (next >= 0)
            choose(next);
    }

    Keys.onLeftPressed: function (event) {
        control.move(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: function (event) {
        control.move(1);
        event.accepted = true;
    }

    Rectangle {
        property real selectedPosition: control.currentIndex

        visible: control.currentIndex >= 0
        x: control.contentPadding + selectedPosition * control.segmentWidth
        y: control.contentPadding
        width: control.segmentWidth
        height: control.height - 2 * control.contentPadding
        radius: Math.min(Theme.controlRadius, height / 2)
        border.width: 1
        border.color: Theme.mix(Theme.border, Theme.accent, 0.48)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.mix(Theme.input, Theme.accent, Theme.dark ? 0.42 : 0.34)
            }
            GradientStop {
                position: 1
                color: Theme.mix(Theme.input, Theme.accent, Theme.dark ? 0.32 : 0.26)
            }
        }

        Behavior on selectedPosition {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Theme.easingStandard
            }
        }
    }

    Row {
        x: control.contentPadding
        y: control.contentPadding
        width: control.width - 2 * control.contentPadding
        height: control.height - 2 * control.contentPadding

        Repeater {
            model: control.options

            delegate: Rectangle {
                id: segment

                required property int index
                required property var modelData

                readonly property bool selected: index === control.currentIndex

                width: control.segmentWidth
                height: parent.height
                radius: Math.min(Theme.controlRadius, height / 2)
                color: !selected && segmentMouse.pressed ? Theme.pressed
                    : (!selected && segmentMouse.containsMouse ? Theme.hover : "transparent")
                opacity: control.optionEnabled(index) ? 1.0 : Theme.disabledOpacity

                Text {
                    anchors.fill: parent
                    leftPadding: 6
                    rightPadding: 6
                    text: segment.modelData.label || segment.modelData.value || ""
                    color: segment.selected ? Theme.accentText : Theme.mix(Theme.mutedText, Theme.text, 0.28)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: segment.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                ControlPointerArea {
                    id: segmentMouse
                    focusTarget: control
                    enabled: control.enabled && control.interactive && control.optionEnabled(segment.index)
                    onClicked: control.choose(segment.index)
                }
            }
        }
    }
}
