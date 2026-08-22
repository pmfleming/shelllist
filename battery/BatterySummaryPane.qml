pragma ComponentBehavior: Bound

import Quickshell
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

    Ui.DetailCard {
        height: 190
        title: "Current status"
        entries: [
            { label: "State", value: Presentation.stateLabel(pane.battery),
                valueColor: pane.battery.plugged ? Ui.Theme.active : Ui.Theme.text,
                valueBold: true },
            { label: "Time", value: Presentation.timeLabel(pane.battery) },
            { label: "Power", value: Number(pane.battery.power_watts || 0).toFixed(1) + " W" },
            { label: "Health", value: pane.battery.health_percent === null
                || pane.battery.health_percent === undefined ? "Unknown"
                : pane.battery.health_percent + "%" },
            { label: "Cycles", value: pane.battery.cycles === null
                || pane.battery.cycles === undefined ? "Unknown"
                : String(pane.battery.cycles) },
            { label: "Charge", value: Math.round(Number(pane.battery.percentage) || 0) + "%" }
        ]
    }

    Ui.DetailColumnCard {
        height: 250
        title: "Battery history · 7 days"

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: Presentation.historyRange(pane.controller.batteryHistory)
            color: Ui.Theme.mutedText
        }

        BatteryHistoryGraph {
            points: pane.controller.batteryHistory.points || []
            metric: "percentage"
            label: "Charge level"
            valueText: Math.round(Number(pane.battery.percentage) || 0) + "%"
            lineColor: pane.battery.warning ? Ui.Theme.warning : Ui.Theme.accent
            minimumMaximum: 100
        }

        BatteryHistoryGraph {
            points: pane.controller.batteryHistory.points || []
            metric: "time_to_full_seconds"
            label: "Time until fully charged"
            valueText: pane.battery.charging
                ? Presentation.duration(pane.battery.time_to_full_seconds) : "Not charging"
            lineColor: Ui.Theme.active
            minimumMaximum: 3600
            positiveOnly: true
        }
    }

    Ui.DetailColumnCard {
        height: 152 + Math.min(8,
            (pane.controller.energyOverview.applications || []).length) * 42
        title: "Application energy"

        Ui.SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: [
                { value: "last-charge", label: "Since last charge" },
                { value: "week", label: "Last 7 days" }
            ]
            value: pane.controller.energyPeriod
            onSelected: function (value) {
                pane.controller.selectEnergyPeriod(value);
            }
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.energyLoading
                ? "Updating estimated energy…"
                : (pane.controller.energyError.length > 0
                    ? pane.controller.energyError
                    : Presentation.energy(
                        pane.controller.energyOverview.total_energy_mwh)
                        + " attributed · "
                        + (pane.controller.energyOverview.energy_confidence
                            || "low") + " confidence")
            color: pane.controller.energyError.length > 0
                ? Ui.Theme.warning : Ui.Theme.mutedText
        }

        Repeater {
            model: (pane.controller.energyOverview.applications || []).slice(0, 8)

            delegate: Item {
                id: energyRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38

                RowLayout {
                    anchors.fill: parent
                    spacing: Ui.Theme.spacingSm

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: Quickshell.iconPath(
                                energyRow.modelData.icon || "application-x-executable",
                                "application-x-executable")
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            anchors.fill: parent
                            visible: appIcon.status === Image.Error
                            text: "󰀻"
                            color: Ui.Theme.accent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Ui.Theme.iconFontFamily
                            font.pixelSize: Ui.Theme.iconSizeSmall
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: energyRow.modelData.name
                                || energyRow.modelData.target_id
                            color: Ui.Theme.text
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 2
                            color: Ui.Theme.border

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1,
                                    Number(energyRow.modelData.share) || 0))
                                height: parent.height
                                radius: parent.radius
                                color: Ui.Theme.accent
                            }
                        }
                    }

                    Text {
                        text: Presentation.energy(energyRow.modelData.energy_mwh)
                        color: Ui.Theme.accent
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: !pane.controller.energyLoading
                && pane.controller.energyError.length === 0
                && (pane.controller.energyOverview.applications || []).length === 0
            text: "No attributable application energy in this period"
            color: Ui.Theme.mutedText
        }
    }

    Ui.DetailColumnCard {
        height: 100
            && (pane.battery.devices || []).length > 1
        title: "Battery device"

        Ui.SegmentedControl {
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

    Ui.DetailCard {
        height: 190
        title: Presentation.deviceName(pane.device)
        entries: [
            { label: "Kernel device", value: pane.device.id || pane.battery.native_path || "Unknown" },
            { label: "Serial", value: pane.device.serial || "Unavailable" },
            { label: "Energy now", value: pane.device.energy_now_wh === null
                || pane.device.energy_now_wh === undefined ? "Unknown"
                : Number(pane.device.energy_now_wh).toFixed(1) + " Wh" },
            { label: "Full capacity", value: pane.device.energy_full_wh === null
                || pane.device.energy_full_wh === undefined ? "Unknown"
                : Number(pane.device.energy_full_wh).toFixed(1) + " Wh" },
            { label: "Design capacity", value: pane.device.energy_full_design_wh === null
                || pane.device.energy_full_design_wh === undefined ? "Unknown"
                : Number(pane.device.energy_full_design_wh).toFixed(1) + " Wh" },
            { label: "Desired range", value: Presentation.desiredRange(pane.protection) }
        ]
    }
}
