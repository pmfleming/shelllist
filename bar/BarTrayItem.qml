import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui

Item {
    id: root

    required property SystemTrayItem item
    implicitWidth: 26
    implicitHeight: 37

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
    function tooltip(): string {
        const title = item.tooltipTitle || item.title || item.id;
        return item.tooltipDescription ? title + "\n" + item.tooltipDescription : title;
    }

    IconImage {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item.icon
    }

    Ui.StateLayer {
        id: pointer

        focusTarget: root
        radius: height / 2
        stateColor: Ui.Theme.text
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) { root.routeClick(mouse.button); }
        onWheel: function (event) { root.scroll(event.angleDelta.y); }
    }

    Controls.ToolTip.visible: pointer.hovered
    Controls.ToolTip.text: root.tooltip()
    Controls.ToolTip.delay: 500
}
