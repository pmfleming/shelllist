pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: control

    property var options: []
    property string value: ""
    property bool interactive: true

    signal selected(string value)

    readonly property int currentIndex: {
        for (let index = 0; index < options.length; ++index)
            if (options[index].value === value)
                return index;
        return options.length > 0 ? 0 : -1;
    }

    implicitHeight: 38
    radius: Theme.controlRadius
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
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: control.options

            delegate: Rectangle {
                id: segment

                required property int index
                required property var modelData

                readonly property bool selected: modelData.value === control.value

                Layout.fillWidth: true
                Layout.fillHeight: true
                color: selected ? Theme.selected : (segmentMouse.containsMouse ? Theme.hover : "transparent")

                Rectangle {
                    visible: segment.index > 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height - 12
                    color: Theme.border
                }

                Text {
                    anchors.fill: parent
                    leftPadding: 6
                    rightPadding: 6
                    text: segment.modelData.label || segment.modelData.value || ""
                    color: segment.selected ? Theme.accent : Theme.text
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
