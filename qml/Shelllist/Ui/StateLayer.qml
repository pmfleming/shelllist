import QtQuick

Item {
    id: root

    property Item focusTarget: parent
    property real radius: Theme.controlRadius
    property color stateColor: Theme.text
    property bool showStateBackground: true
    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton
    property bool consumeWheel: false
    property real hoverOpacity: 0.08
    property real pressedOpacity: 0.14
    property real pressX: -1
    property real pressY: -1
    readonly property real effectivePressX: pressX >= 0 ? pressX : width / 2
    readonly property real effectivePressY: pressY >= 0 ? pressY : height / 2
    readonly property bool containsMouse: pointer.containsMouse
    readonly property bool hovered: containsMouse
    readonly property bool pressed: pointer.pressed

    signal clicked(var mouse)
    signal doubleClicked(var mouse)
    signal wheel(var wheel)

    anchors.fill: parent
    enabled: interactive && (!focusTarget || focusTarget.enabled)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.stateColor
        opacity: root.showStateBackground
            ? (root.pressed ? root.pressedOpacity : (root.hovered ? root.hoverOpacity : 0))
            : 0

        Behavior on opacity {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Theme.easingStandard
            }
        }
    }

    Rectangle {
        id: ripple

        property real diameter: 0

        x: root.effectivePressX - diameter / 2
        y: root.effectivePressY - diameter / 2
        width: diameter
        height: diameter
        radius: diameter / 2
        color: root.stateColor
        opacity: 0

        ParallelAnimation {
            id: rippleAnimation

            NumberAnimation {
                target: ripple
                property: "diameter"
                from: 0
                to: Math.hypot(root.width, root.height) * 1.35
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: ripple
                    property: "opacity"
                    from: 0.12
                    to: 0.08
                    duration: Math.round(Theme.animationNormal * 0.55)
                }
                NumberAnimation {
                    target: ripple
                    property: "opacity"
                    to: 0
                    duration: Math.round(Theme.animationNormal * 0.45)
                }
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: enabled
        acceptedButtons: root.acceptedButtons
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function (mouse) {
            root.pressX = mouse.x;
            root.pressY = mouse.y;
            if (root.focusTarget)
                root.focusTarget.forceActiveFocus();
            if (!Theme.noAnimations) {
                rippleAnimation.stop();
                ripple.diameter = 0;
                ripple.opacity = 0.12;
                rippleAnimation.start();
            }
        }
        onClicked: function (mouse) { root.clicked(mouse); }
        onDoubleClicked: function (mouse) { root.doubleClicked(mouse); }
        onWheel: function (event) {
            root.wheel(event);
            event.accepted = root.consumeWheel;
        }
    }
}
