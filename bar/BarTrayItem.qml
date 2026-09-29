import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root

    required property SystemTrayItem item
    implicitWidth: 32
    implicitHeight: 37
    Accessible.role: Accessible.Button
    Accessible.name: item.title || item.id
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: width / 2
        color: "transparent"
        border.width: root.item.status === Status.NeedsAttention ? 2 : 0
        border.color: Ui.Theme.danger
    }

    function displayMenu(): void {
        if (item.hasMenu)
            item.display(root.QsWindow.window, Math.round(width / 2), height);
    }
    function routeClick(button: int): void {
        if (button === Qt.RightButton || item.onlyMenu)
            displayMenu();
        else if (button === Qt.MiddleButton)
            item.secondaryActivate();
        else
            item.activate();
    }
    function scroll(delta: int): void {
        if (delta !== 0)
            item.scroll(Math.round(delta / 8), false);
    }
    IconImage {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item.icon
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
