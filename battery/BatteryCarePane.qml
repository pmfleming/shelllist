pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryFeedback.js" as Presentation

Column {
    id: pane

    required property BatteryController controller
    required property var battery
    required property var device
    required property var protection
    signal calibrationRequested()

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        objectName: "batteryDeviceCard"
        visible: (pane.battery.devices || []).length > 1
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Device")
            accessibleName: qsTr("Battery device")
            Ui.SegmentedControl {
            objectName: "batteryDeviceSelector"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: (pane.battery.devices || []).map(function (batteryDevice) {
                return {
                    value: batteryDevice.id,
                    label: Presentation.deviceName(batteryDevice)
                };
            })
            value: pane.device.id || ""
            interactive: !pane.controller.actionInFlight
            onSelected: function (value) {
                pane.controller.selectDevice(value);
            }
            }
        }
    }

    BatteryProtectionPane {
        controller: pane.controller
        battery: pane.battery
        device: pane.device
        protection: pane.protection
        onCalibrationRequested: pane.calibrationRequested()
    }

    Ui.DetailColumnCard {
        objectName: "batteryHealthCard"
        title: qsTr("Battery health")
        RowLayout {
            Layout.fillWidth: true
            BatteryIconValue {
                Layout.fillWidth: true
                icons: ["shield"]
                text: pane.device.health_percent == null ? qsTr("Unknown") : pane.device.health_percent + "%"
                description: qsTr("Full capacity / design capacity: %1").arg(text)
                pixelSize: Ui.Theme.fontSizeDisplay
                color: Ui.Theme.text
            }
            BatteryIconValue {
                Layout.fillWidth: true
                icons: ["autorenew"]
                text: pane.device.cycles == null ? qsTr("Unknown") : String(pane.device.cycles)
                description: qsTr("Charge cycles: %1").arg(text)
                pixelSize: Ui.Theme.fontSizeDisplay
                color: Ui.Theme.text
            }
        }
    }

    Ui.DetailSection {
        informationOnly: true
        objectName: "batteryHardwareDetails"
        Ui.DetailCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            title: qsTr("Hardware")
            entries: [
                {
                    label: qsTr("Battery"),
                    value: Presentation.deviceName(pane.device)
                },
                {
                    label: "Energy now",
                    value: pane.device.display?.energy_now || qsTr("Unknown")
                },
                {
                    label: "Full capacity",
                    value: pane.device.display?.energy_full || qsTr("Unknown")
                },
                {
                    label: "Design capacity",
                    value: pane.device.display?.energy_design || qsTr("Unknown")
                },
                {
                    label: "Desired range",
                    value: pane.device.display?.desired_range || qsTr("Not configured")
                },
                {
                    label: "Kernel device",
                    value: pane.device.id || pane.battery.native_path || "Unknown"
                },
                {
                    label: "Serial",
                    value: pane.device.serial || "Unavailable"
                }
            ]
        }
    }
}
