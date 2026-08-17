pragma ComponentBehavior: Bound

import Quickshell.Services.SystemTray
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root

    required property int layoutDensity
    visible: layoutDensity === 0 && trayRepeater.count > 0
    implicitWidth: visible ? trayRow.implicitWidth + 12 : 0
    implicitHeight: 37

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.56)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.controlBorder, 0.72)
    }

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: 3

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: BarTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                height: root.height
            }
        }
    }
}
