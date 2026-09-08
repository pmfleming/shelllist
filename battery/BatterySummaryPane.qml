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

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailCard {
        height: 142
        title: "Current status"
        entries: [
            { label: "State", value: Presentation.stateLabel(pane.battery),
                valueColor: pane.battery.plugged ? Ui.Theme.active : Ui.Theme.text,
                valueBold: true },
            { label: "Time", value: Presentation.timeLabel(pane.battery) },
            { label: "Power", value: Number(pane.battery.power_watts || 0).toFixed(1) + " W" }
        ]
    }

    BatteryHistoryCard {
        history: pane.controller.batteryHistory
        battery: pane.battery
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

                        Ui.ThemeText {
                            Layout.fillWidth: true
                            text: energyRow.modelData.name
                                || energyRow.modelData.target_id
                            elide: Text.ElideRight
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

                    Ui.ThemeText {
                        text: Presentation.energy(energyRow.modelData.energy_mwh)
                        color: Ui.Theme.accent
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
}
