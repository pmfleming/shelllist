pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "SliderScale.js" as Scale

Controls.Slider {
    id: slider
    property bool browseFocused: false
    // Optional non-linear ruler. Values and accessibility stay in domain units.
    property list<real> scaleValues: []
    property real minimumValue: Math.min(from, to)
    property real maximumValue: Math.max(from, to)
    property real peerValue: NaN
    property real editingPeerValue: NaN
    readonly property bool stepped: scaleValues.length > 1
    readonly property real logicalPosition: stepped ? Scale.position(scaleValues, value) : position
    readonly property real trackPosition: stepped ? (mirrored ? 1 - logicalPosition : logicalPosition) : visualPosition
    readonly property bool onScale: !stepped || (value >= scaleValues[0] && value <= scaleValues[scaleValues.length - 1])
    signal editRejected

    function allowed(candidate: real): bool {
        return Number.isFinite(candidate) && candidate >= minimumValue && candidate <= maximumValue;
    }
    function stage(candidate: real): void {
        if (!enabled || !allowed(candidate) || candidate === value) return;
        forceActiveFocus();
        value = candidate;
        publishEdit();
    }
    function stepScale(direction: int): void {
        stage(Scale.adjacent(scaleValues, value, direction, minimumValue, maximumValue));
    }
    function accessibleStep(direction: int): void {
        if (!enabled) return;
        if (stepped) { stepScale(direction); return; }
        forceActiveFocus();
        const previous = value;
        if (direction > 0) increase(); else decrease();
        if (value !== previous) {
            publishEdit();
            finishPointerEdit();
        }
    }
    Accessible.onIncreaseAction: accessibleStep(1)
    Accessible.onDecreaseAction: accessibleStep(-1)
    // Only continuous preview settings (volume/brightness) opt in.
    property alias livePreview: transaction.livePreview
    readonly property alias editSession: transaction
    FieldEditSession {
        id: transaction
        owner: slider
        valueProperty: "value"
        value: slider.value
        onRestoreRequested: function (value) { slider.value = value; }
        onActiveChanged: if (active) slider.editingPeerValue = slider.peerValue
        onPublishRequested: function (value) {
            const samePeer = slider.peerValue === slider.editingPeerValue || (isNaN(slider.peerValue) && isNaN(slider.editingPeerValue));
            if (!slider.stepped || (slider.allowed(value) && samePeer)) slider.edited(value);
            else slider.editRejected();
        }
        onFinished: function (saved) { if (saved || livePreview) slider.editingFinished(); }
    }
    function publishEdit(): void {
        if ((!transaction.active || transaction.livePreview) && (!stepped || allowed(value)))
            edited(value);
    }
    function finishPointerEdit(): void {
        if (!transaction.active)
            editingFinished();
    }

    signal edited(real value)
    signal editingFinished

    function moveToBoundary(boundary: real): void {
        if (!enabled || value === boundary)
            return;
        value = boundary;
        publishEdit();
        finishPointerEdit();
    }

    implicitWidth: horizontal ? 200 : 44
    implicitHeight: horizontal ? 44 : 200
    padding: 0
    live: true
    snapMode: Controls.Slider.SnapAlways
    activeFocusOnTab: enabled
    onMoved: publishEdit()
    onPressedChanged: if (!pressed)
        finishPointerEdit()
    Keys.onPressed: function (event) {
        event.accepted = false;
        transaction.handleKey(event);
        if (event.accepted) return;
        if (stepped && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End].includes(event.key)) {
            if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                const choices = Scale.choices(scaleValues, minimumValue, maximumValue);
                if (choices.length) stage(event.key === Qt.Key_Home ? choices[0] : choices[choices.length - 1]);
            } else {
                const direction = event.key === Qt.Key_Up ? 1 : event.key === Qt.Key_Down ? -1 : (event.key === Qt.Key_Right ? 1 : -1) * (mirrored ? -1 : 1);
                stepScale(direction);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
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
        readonly property real split: 2 + slider.trackPosition * Math.max(0, length - 4)
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

    // Non-linear pointer mapping uses the very same fixed ruler as keys/paint.
    MouseArea {
        anchors.fill: parent
        enabled: slider.stepped && slider.enabled
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        function update(pointerX: real): void {
            const fraction = Math.max(0, Math.min(1, (pointerX - 2) / Math.max(1, width - 4)));
            slider.stage(Scale.at(slider.scaleValues, slider.mirrored ? 1 - fraction : fraction, slider.minimumValue, slider.maximumValue));
        }
        onPressed: function(mouse) { slider.forceActiveFocus(); update(mouse.x); }
        onPositionChanged: function(mouse) { if (pressed && (!slider.editSession.navigation || slider.editSession.active)) update(mouse.x); }
        onCanceled: if (slider.editSession.active && slider.editSession.navigation) slider.editSession.navigation.retreat()
    }

    Item {
        anchors.fill: parent
        visible: slider.stepped
        clip: true
        // Hatched unavailable regions are passive and do not intercept input.
        Repeater {
            model: slider.stepped ? [
                {start: slider.mirrored ? 1 - Scale.position(slider.scaleValues, slider.minimumValue) : 0, extent: Scale.position(slider.scaleValues, slider.minimumValue)},
                {start: slider.mirrored ? 0 : Scale.position(slider.scaleValues, slider.maximumValue), extent: 1 - Scale.position(slider.scaleValues, slider.maximumValue)}
            ] : []
            Item {
                id: blocked
                required property var modelData
                x: modelData.start * (parent?.width ?? 0)
                width: modelData.extent * (parent?.width ?? 0)
                height: 16
                y: ((parent?.height ?? 0) - height) / 2
                clip: true
                Repeater {
                    model: Math.ceil(blocked.width / 6)
                    Rectangle {
                        required property int index
                        x: index * 6
                        width: 1
                        height: 24
                        rotation: 45
                        color: Theme.mutedText
                        opacity: 0.55
                    }
                }
            }
        }
        Rectangle {
            objectName: "sliderPeerMarker"
            readonly property real peerPosition: Scale.position(slider.scaleValues, slider.peerValue)
            visible: Number.isFinite(slider.peerValue) && slider.peerValue >= slider.scaleValues[0] && slider.peerValue <= slider.scaleValues[slider.scaleValues.length - 1]
            x: 2 + (slider.mirrored ? 1 - peerPosition : peerPosition) * (parent.width - 4) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 24
            color: Theme.mutedText
        }
    }

    handle: Item {
        visible: slider.onScale
        // Native Slider owns mapping, dragging, touch and accessible actions.
        // The handle position must agree with its value immediately, including
        // keyboard edits, RTL and vertical orientation. Only thickness springs.
        x: slider.leftPadding + (slider.horizontal ? slider.trackPosition * (slider.availableWidth - width) : (slider.availableWidth - width) / 2)
        y: slider.topPadding + (slider.horizontal ? (slider.availableHeight - height) / 2 : slider.trackPosition * (slider.availableHeight - height))
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
        active: slider.activeFocus || slider.browseFocused
        editing: slider.editSession.active
        cornerRadius: Theme.pressedCornerRadius
        horizontalIndicator: slider.horizontal
    }
}
