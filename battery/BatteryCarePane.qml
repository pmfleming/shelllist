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
        objectName: "batteryChargeNotificationCard"
        title: qsTr("Charge notification")

        Ui.ToggleRow {
            objectName: "batteryChargeNotificationToggle"
            readonly property int chargeTarget: pane.protection.enabled && !pane.protection.charge_once_active ? Number(pane.protection.end_percent ?? 100) : 100
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: chargeTarget < 100 ? qsTr("Notify at charge limit (%1%)").arg(chargeTarget) : qsTr("Notify at 100%")
            checked: pane.controller.alertDraft.notify_when_full
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateNotifyWhenFull(!checked)
        }

        Ui.SaveStatusLabel {
            objectName: "batteryChargeNotificationSaveStatus"
            Layout.fillWidth: true
            visible: pane.controller.alertDraftDirty || pane.controller.alertOperationActive || pane.controller.alertSaveError.length > 0
            text: pane.controller.alertSaveStatus
            valid: pane.controller.alertDraftValid
            error: pane.controller.alertSaveError
            saving: pane.controller.alertOperationActive
        }
    }

    Ui.DetailColumnCard {
        objectName: "batteryDeviceCard"
        visible: (pane.battery.devices || []).length > 1
        title: qsTr("Battery device")

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

    BatteryProtectionPane {
        controller: pane.controller
        battery: pane.battery
        device: pane.device
        protection: pane.protection
    }

    Ui.DetailCard {
        objectName: "batteryHealthCard"
        title: qsTr("Battery health")
        entries: [
            {
                label: qsTr("Health"),
                value: pane.device.health_percent == null ? qsTr("Unknown") : pane.device.health_percent + "%"
            },
            {
                label: qsTr("Cycles"),
                value: pane.device.cycles == null ? qsTr("Unknown") : String(pane.device.cycles)
            }
        ]
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
                    label: "Energy now",
                    value: pane.device.energy_now_wh === null || pane.device.energy_now_wh === undefined ? "Unknown" : Number(pane.device.energy_now_wh).toFixed(1) + " Wh"
                },
                {
                    label: "Full capacity",
                    value: pane.device.energy_full_wh === null || pane.device.energy_full_wh === undefined ? "Unknown" : Number(pane.device.energy_full_wh).toFixed(1) + " Wh"
                },
                {
                    label: "Design capacity",
                    value: pane.device.energy_full_design_wh === null || pane.device.energy_full_design_wh === undefined ? "Unknown" : Number(pane.device.energy_full_design_wh).toFixed(1) + " Wh"
                },
                {
                    label: "Desired range",
                    value: Presentation.desiredRange(pane.protection)
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
