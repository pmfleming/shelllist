pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property BatteryController controller
    required property var battery
    required property var device
    required property var protection

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    BatterySummaryPane {
        controller: pane.controller
        battery: pane.battery
        device: pane.device
        protection: pane.protection
    }

    BatteryProtectionPane {
        controller: pane.controller
        battery: pane.battery
        device: pane.device
        protection: pane.protection
    }
}
