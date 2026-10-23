pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryFeedback.js" as Presentation

Column {
    id: pane

    required property BatteryController controller
    required property var battery

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        objectName: "powerModeCard"

        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Power mode")
            BatteryProfileSelector {
                objectName: "batteryPowerModeProfile"
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                accessibleName: qsTr("Power mode")
                options: pane.controller.profileOptions
                value: pane.controller.powerProfile.profile || ""
                interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                onSelected: function (value) {
                    pane.controller.setPowerProfile(value);
                }
            }
        }

        Ui.FeedbackSource {
            active: !pane.controller.powerProfile.available
            text: qsTr("power-profiles-daemon is unavailable")
            summaryText: qsTr("Power profiles unavailable")
            tone: "warning"
        }
        Ui.FeedbackSource {
            active: !!pane.controller.powerProfile.performance_degraded
            text: qsTr("Performance is limited: %1").arg(pane.controller.powerProfile.performance_degraded)
            summaryText: qsTr("Performance is limited")
            tone: "warning"
        }

        Repeater {
            model: pane.controller.powerProfile.active_holds || []

            delegate: Ui.FeedbackSource {
                required property var modelData
                text: Presentation.holdSummary(modelData)
                summaryText: qsTr("An application holds the power profile")
            }
        }
    }

    BatteryHistoryCard {
        objectName: "batteryHistoryCard"
        history: pane.controller.batteryHistory
        battery: pane.battery
        range: String(pane.controller.historyHours)
        onRangeRequested: hours => pane.controller.requestHistory(hours)
    }

    Ui.DetailColumnCard {
        BatterySectionHeading {
            Layout.fillWidth: true
            title: qsTr("Application energy")
            helpText: qsTr("Plug: since last charge. 7d: last seven days. Energy is estimated attribution, not direct per-application measurement. Confidence: %1.").arg(pane.controller.energyOverview.energy_confidence || "low")
        }

        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Period")
            accessibleName: qsTr("Application energy period")
            Ui.SegmentedControl {
            objectName: "batteryEnergyPeriod"
            iconOnly: true
            Accessible.name: qsTr("Application energy period")
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: [
                {
                    value: "last-charge",
                    label: qsTr("Since last charge"),
                    icon: "battery_charging_full"
                },
                {
                    value: "week",
                    label: qsTr("Last 7 days"),
                    shortLabel: "7d"
                }
            ]
            value: pane.controller.energyPeriod
            onSelected: function (value) {
                pane.controller.selectEnergyPeriod(value);
            }
            }
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            text: pane.controller.energyError || pane.controller.energyOverview.total_energy_mwh === undefined ? qsTr("Unavailable") : (pane.controller.energyOverview.total_energy_label || qsTr("Unavailable"))
            font.pixelSize: Ui.Theme.formValueSize
            Accessible.name: qsTr("Estimated attributed energy: %1. Confidence: %2").arg(text).arg(pane.controller.energyOverview.energy_confidence || "low")
        }
        Ui.FeedbackSource {
            text: pane.controller.energyError || (pane.controller.energyLoading ? qsTr("Updating estimated energy…") : "")
            summaryText: pane.controller.energyError ? qsTr("Energy unavailable") : qsTr("Updating energy…")
            tone: pane.controller.energyError ? "warning" : "info"
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
                            source: Quickshell.iconPath(energyRow.modelData.icon || "application-x-executable", "application-x-executable")
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
                            text: energyRow.modelData.name || energyRow.modelData.target_id
                            elide: Text.ElideRight
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 2
                            color: Ui.Theme.border

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Number(energyRow.modelData.share) || 0))
                                height: parent.height
                                radius: parent.radius
                                color: Ui.Theme.accent
                            }
                        }
                    }

                    Ui.ThemeText {
                        text: energyRow.modelData.energy_label || qsTr("Unavailable")
                        color: Ui.Theme.accent
                        font.pixelSize: Ui.Theme.metadataSize
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }

        Ui.ContentState {
            objectName: "energyContentState"
            Layout.fillWidth: true
            visible: (pane.controller.energyOverview.applications || []).length === 0
            compact: true
            active: pane.controller.uiActive
            icon: "bolt"
            kind: pane.controller.energyError ? "unavailable" : pane.controller.energyLoading ? "loading" : "empty"
            text: pane.controller.energyError || (pane.controller.energyLoading ? qsTr("Reading application energy…") : qsTr("No attributable application energy in this period"))
        }
    }
}
