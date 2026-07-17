pragma ComponentBehavior: Bound

import QtQuick
import "."

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
        return options.length > 0 ? 0 : -1;
    }

    implicitHeight: 38
    radius: height / 4
    color: Theme.input
    border.color: activeFocus ? Theme.strongBorder : Theme.border
    border.width: 1
    opacity: interactive ? 1.0 : 0.55
    clip: true
    activeFocusOnTab: interactive

    function choose(index) {
        if (!interactive || index < 0 || index >= options.length)
            return;
        const nextValue = options[index].value;
        if (nextValue !== value)
            selected(nextValue);
    }

    function move(delta) {
        if (options.length === 0)
            return;
        choose(Math.max(0, Math.min(options.length - 1, currentIndex + delta)));
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
        radius: height / 2
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
                duration: 170
                easing.type: Easing.InOutCubic
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
                radius: height / 2
                color: !selected && segmentMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.fill: parent
                    leftPadding: 6
                    rightPadding: 6
                    text: segment.modelData.label || segment.modelData.value || ""
                    color: segment.selected ? Theme.accentText : Theme.mix(Theme.mutedText, Theme.text, 0.28)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: segment.selected ? Font.DemiBold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: segmentMouse

                    anchors.fill: parent
                    enabled: control.interactive
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        control.forceActiveFocus();
                        control.choose(segment.index);
                    }
                }
            }
        }
    }
}
