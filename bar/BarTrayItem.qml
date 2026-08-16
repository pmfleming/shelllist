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

    onClicked: function (mouse) {
        if (mouse.button === Qt.RightButton) {
            displayMenu();
        } else if (mouse.button === Qt.MiddleButton) {
            item.secondaryActivate();
        } else if (item.onlyMenu) {
            displayMenu();
        } else {
            item.activate();
        }
    }
    onWheel: function (wheel) {
        if (wheel.angleDelta.y !== 0)
            item.scroll(Math.round(wheel.angleDelta.y / 8), false);
    }

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
    Controls.ToolTip.text: {
        const title = root.item.tooltipTitle || root.item.title || root.item.id;
        return root.item.tooltipDescription ? title + "\n" + root.item.tooltipDescription : title;
    }
    Controls.ToolTip.delay: 500
}
