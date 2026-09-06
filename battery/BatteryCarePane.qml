pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Column {
    id: pane

    required property BatteryController controller
    required property var battery
    required property var device
    required property var protection

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        objectName: "batteryDeviceCard"
        visible: (pane.battery.devices || []).length > 1
        height: 100
        title: "Battery device"

        Ui.SegmentedControl {
            objectName: "batteryDeviceSelector"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: (pane.battery.devices || []).map(function (batteryDevice) {
                return { value: batteryDevice.id,
                    label: Presentation.deviceName(batteryDevice) };
            })
            value: pane.device.id || ""
            interactive: !pane.controller.actionInFlight
            onSelected: function (value) { pane.controller.selectDevice(value); }
        }
    }

    BatteryProtectionPane {
        controller: pane.controller
        battery: pane.battery
        device: pane.device
        protection: pane.protection
    }

    Ui.DetailCard {
        objectName: "batteryHealthCard"
        height: 240
        title: "Health & hardware"
        entries: [
            { label: "Health", value: pane.device.health_percent === null
                || pane.device.health_percent === undefined ? "Unknown"
                : pane.device.health_percent + "%" },
            { label: "Cycles", value: pane.device.cycles === null
                || pane.device.cycles === undefined ? "Unknown"
                : String(pane.device.cycles) },
            { label: "Energy now", value: pane.device.energy_now_wh === null
                || pane.device.energy_now_wh === undefined ? "Unknown"
                : Number(pane.device.energy_now_wh).toFixed(1) + " Wh" },
            { label: "Full capacity", value: pane.device.energy_full_wh === null
                || pane.device.energy_full_wh === undefined ? "Unknown"
                : Number(pane.device.energy_full_wh).toFixed(1) + " Wh" },
            { label: "Design capacity", value: pane.device.energy_full_design_wh === null
                || pane.device.energy_full_design_wh === undefined ? "Unknown"
                : Number(pane.device.energy_full_design_wh).toFixed(1) + " Wh" },
            { label: "Desired range", value: Presentation.desiredRange(pane.protection) },
            { label: "Kernel device", value: pane.device.id || pane.battery.native_path || "Unknown" },
            { label: "Serial", value: pane.device.serial || "Unavailable" }
        ]
    }
}
