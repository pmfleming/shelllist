import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui

MouseArea {
    id: root

    required property SystemTrayItem item
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    implicitWidth: 24
    implicitHeight: 51

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

    onClicked: function (mouse) { routeClick(mouse.button); }
    onWheel: function (wheel) { scroll(wheel.angleDelta.y); }

    Rectangle {
        anchors.fill: parent
        color: root.containsMouse ? Ui.Theme.hover : "transparent"
    }

    IconImage {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item.icon
    }

    Controls.ToolTip.visible: root.containsMouse
    Controls.ToolTip.text: root.tooltip()
    Controls.ToolTip.delay: 500
}
