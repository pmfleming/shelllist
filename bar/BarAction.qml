import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root

    required property string text
    property color foreground: Ui.Theme.text
    property color hoverColor: Ui.Theme.hover
    property color backgroundColor: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.56)
    property color borderColor: Ui.Theme.withAlpha(Ui.Theme.controlBorder, 0.72)
    property int horizontalPadding: 10
    property int minimumWidth: 0
    property bool interactive: true
    property alias elide: label.elide
    property alias fontWeight: label.font.weight

    signal primaryTriggered
    signal secondaryTriggered
    signal middleTriggered
    signal wheelUp
    signal wheelDown

    function routeClick(button: int): void {
        if (!interactive)
            return;
        const handlers = ({});
        handlers[Qt.LeftButton] = primaryTriggered;
        handlers[Qt.RightButton] = secondaryTriggered;
        handlers[Qt.MiddleButton] = middleTriggered;
        if (handlers[button])
            handlers[button]();
    }

    function routeWheel(delta: int): void {
        if (!interactive || delta === 0)
            return;
        (delta > 0 ? wheelUp : wheelDown)();
    }

    implicitWidth: Math.max(minimumWidth, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: 37

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.backgroundColor
        border.width: 1
        border.color: root.borderColor

        Behavior on color {
            enabled: !Ui.Theme.noAnimations
            ColorAnimation { duration: Ui.Theme.animationFast }
        }
    }

    Text {
        id: label
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        text: root.text
        color: root.foreground
        font.family: Ui.Theme.iconFontFamily
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone

        Behavior on color {
            enabled: !Ui.Theme.noAnimations
            ColorAnimation { duration: Ui.Theme.animationFast }
        }
    }

    Ui.StateLayer {
        id: pointer

        focusTarget: root
        radius: height / 2
        stateColor: root.foreground
        showStateBackground: true
        hoverOpacity: 0.09
        pressedOpacity: 0.15
        interactive: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) { root.routeClick(mouse.button); }
        onWheel: function (event) { root.routeWheel(event.angleDelta.y); }
    }

}
