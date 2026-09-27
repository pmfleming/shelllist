pragma ComponentBehavior: Bound

import QtQuick
import "SegmentedNavigation.js" as Navigation

Rectangle {
    id: control

    property var options: []
    property string value: ""
    property bool interactive: true

    signal selected(string value)

    readonly property int contentPadding: 1
    readonly property real segmentWidth: options.length > 0 ? Math.max(0, width - 2 * contentPadding) / options.length : 0
    readonly property int currentIndex: {
        for (let index = 0; index < options.length; ++index)
            if (options[index].value === value)
                return index;
        return -1;
    }

    implicitHeight: Theme.controlHeight
    radius: height / 2
    color: Theme.surface
    border.color: Theme.controlBorder
    border.width: 1
    opacity: enabled && (interactive || activeFocus) ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled && (interactive || activeFocus)
    LayoutMirroring.childrenInherit: true
    Accessible.role: Accessible.Grouping

    function optionEnabled(index) {
        return Navigation.optionEnabled(options, index);
    }

    function choose(index) {
        if (!enabled || !interactive || !optionEnabled(index))
            return;
        const nextValue = options[index].value;
        if (nextValue !== value)
            selected(nextValue);
    }

    function move(delta) {
        const next = Navigation.nextEnabledIndex(options, currentIndex, delta);
        if (next >= 0)
            choose(next);
    }

    Keys.onLeftPressed: function (event) {
        control.move(control.LayoutMirroring.enabled ? 1 : -1);
        event.accepted = true;
    }
    Keys.onRightPressed: function (event) {
        control.move(control.LayoutMirroring.enabled ? -1 : 1);
        event.accepted = true;
    }

    Row {
        x: control.contentPadding
        y: control.contentPadding
        width: control.width - 2 * control.contentPadding
        height: Math.max(0, control.height - 2 * control.contentPadding)

        Repeater {
            model: control.options

            delegate: Rectangle {
                id: segment
                required property int index
                required property var modelData

                readonly property bool selected: index === control.currentIndex
                readonly property bool first: index === (control.LayoutMirroring.enabled ? control.options.length - 1 : 0)
                readonly property bool last: index === (control.LayoutMirroring.enabled ? 0 : control.options.length - 1)
                objectName: "segment-" + modelData.value
                width: control.segmentWidth
                // Delegates may temporarily have no parent during model replacement.
                height: Math.max(0, control.height - 2 * control.contentPadding)
                topLeftRadius: first ? height / 2 : 0
                bottomLeftRadius: topLeftRadius
                topRightRadius: last ? height / 2 : 0
                bottomRightRadius: topRightRadius
                // Foreground, fill, selection and focus move together. A sliding
                // fill would briefly leave the new foreground on the old surface.
                color: selected ? Theme.selected : Theme.surface
                enabled: control.enabled && control.interactive && control.optionEnabled(index)
                opacity: control.optionEnabled(index) ? 1.0 : Theme.disabledOpacity
                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.name: modelData.label || modelData.value || ""
                Accessible.checked: selected
                Accessible.focused: control.activeFocus && selected
                Accessible.onPressAction: control.choose(index)
                Accessible.onToggleAction: control.choose(index)

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: segment.topLeftRadius
                    bottomLeftRadius: segment.bottomLeftRadius
                    topRightRadius: segment.topRightRadius
                    bottomRightRadius: segment.bottomRightRadius
                    color: segment.selected ? Theme.selectedText : Theme.text
                    opacity: segmentMouse.pressed ? 0.12 : (segmentMouse.containsMouse ? 0.08 : 0)
                }
                ThemeText {
                    anchors.fill: parent
                    leftPadding: 8
                    rightPadding: 8
                    text: segment.Accessible.name
                    color: segment.selected ? Theme.selectedText : Theme.text
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: segment.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: !segment.last
                    x: parent.width - width
                    width: 1
                    height: parent.height
                    color: Theme.controlBorder
                }
                FocusRing {
                    active: control.activeFocus && segment.selected
                    cornerRadius: segment.height / 2
                    ringColor: Theme.selectedText
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
    FocusRing {
        active: control.activeFocus && control.currentIndex < 0
        cornerRadius: control.radius
    }
}
