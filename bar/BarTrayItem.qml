import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root

    required property SystemTrayItem item
    // Native menu host; the offscreen platform boundary supplies a recording host.
    property QtObject menuWindow: root.QsWindow.window
    implicitWidth: 32
    implicitHeight: 37
    Accessible.role: Accessible.Button
    Accessible.name: item ? item.title || item.id : ""
    Accessible.onPressAction: root.routeClick(Qt.LeftButton)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: width / 2
        color: "transparent"
        border.width: root.item && root.item.status === Status.NeedsAttention ? 2 : 0
        border.color: Ui.Theme.danger
    }

    function displayMenu(): void {
        if (enabled && visible && item && item.hasMenu)
            item.display(menuWindow, Math.round(width / 2), height);
    }
    function routeClick(button: int): void {
        if (!enabled || !visible || !item)
            return;
        if (button === Qt.RightButton || item.onlyMenu)
            displayMenu();
        else if (button === Qt.MiddleButton)
            item.secondaryActivate();
        else
            item.activate();
    }
    function scroll(delta: int): void {
        if (enabled && visible && item && delta !== 0)
            item.scroll(Math.round(delta / 8), false);
    }
    IconImage {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item ? root.item.icon : ""
    }

    Ui.StateLayer {
        focusTarget: root
        radius: height / 2
        stateColor: Ui.Theme.text
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        consumeWheel: true
        onClicked: function (mouse) {
            root.routeClick(mouse.button);
        }
        onWheel: function (event) {
            root.scroll(event.angleDelta.y);
        }
    }
}
