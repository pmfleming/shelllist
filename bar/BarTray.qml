pragma ComponentBehavior: Bound

import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root
    spacing: 6
    leftPadding: trayRepeater.count > 0 ? 10 : 0
    rightPadding: trayRepeater.count > 0 ? 10 : 0

    Repeater {
        id: trayRepeater
        model: SystemTray.items

        delegate: BarTrayItem {
            required property SystemTrayItem modelData
            item: modelData
        }
    }
}
