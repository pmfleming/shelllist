import QtQuick
import Shelllist.Ui as Ui

Ui.ActionButton {
    id: root
    required property string text
    property color foreground: Ui.Theme.text
    icon: text
    iconSize: 20
    labelColor: foreground
    accessibleName: text
    implicitWidth: 32
    implicitHeight: 32
    activeFocusOnTab: false
    browseIndicatorVisible: false
    backgroundColor: "transparent"
    borderColor: "transparent"
    border.width: 0
    // This adapter retains multi-button/wheel routes instead of also accepting
    // clicks through PointerActionControl's ordinary single-click receiver.
    pointerEnabled: false
    onClicked: primaryTriggered()

    signal primaryTriggered
    signal secondaryTriggered
    signal middleTriggered
    signal wheelUp
    signal wheelDown

    function routeClick(button: int): void {
        if (!enabled || !interactive) return;
        if (button === Qt.LeftButton) activate();
        else if (button === Qt.RightButton) secondaryTriggered();
        else if (button === Qt.MiddleButton) middleTriggered();
    }
    function routeWheel(delta: int): void {
        if (!enabled || !interactive || delta === 0) return;
        if (delta > 0) wheelUp();
        else wheelDown();
    }
    Ui.StateLayer {
        focusTarget: root
        radius: root.radius
        stateColor: root.foreground
        showStateBackground: true
        hoverOpacity: 0.09
        pressedOpacity: 0.15
        interactive: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        consumeWheel: false
        onClicked: function (mouse) { root.routeClick(mouse.button); }
        onWheel: function (event) { root.routeWheel(event.angleDelta.y); }
    }
}
