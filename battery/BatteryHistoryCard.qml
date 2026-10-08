pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Rectangle {
    id: card

    required property var history
    required property var battery
    property string range: "6"
    readonly property var forecast: battery.forecast || ({
            limit: null,
            target: 100,
            seconds: 0
        })
    readonly property string estimateText: History.forecastLabel(battery)
    readonly property var points: History.windowPoints(history.points || [], Number(range), (battery.history || {}).current_point || history.current_point)
    readonly property bool powerAvailable: battery.available && battery.power_available === true && History.nonnegative(battery.power_watts)
    readonly property bool exceptionalState: !battery.available || ["charging-inhibited", "calibrating", "pending-charge", "pending-discharge"].includes(battery.state)

    width: parent ? parent.width : 0
    implicitHeight: content.implicitHeight + 2 * Ui.Theme.spacingMd
    height: implicitHeight
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.width: 0

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingMd

        BatterySectionHeading {
            Layout.fillWidth: true
            title: qsTr("Battery history")
            helpText: qsTr("Clock: time to the battery target. Arrows: power into or out of the battery. Line: observed charge; the dotted extension is a forecast. Colored areas: discharging and charging power. Time excludes suspended intervals.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingMd

            Ui.GlyphLabel {
                glyph: card.forecast.seconds > 0 ? "schedule" : (card.battery.plugged ? "power" : "battery_full")
                color: card.battery.plugged ? Ui.Theme.active : Ui.Theme.accent
                font.pixelSize: Ui.Theme.iconSizeLarge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ThemeText {
                    objectName: "batteryHistoryEstimate"
                    Layout.fillWidth: true
                    text: card.forecast.seconds > 0 ? "~" + Presentation.duration(card.forecast.seconds) : card.estimateText
                    font.pixelSize: card.forecast.seconds > 0 ? Ui.Theme.fontSizeTitle : Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightBold
                    wrapMode: Text.WordWrap
                }

                BatteryIconValue {
                    objectName: "batteryForecastTarget"
                    Layout.fillWidth: true
                    visible: card.forecast.seconds > 0
                    icons: ["arrow_forward", "battery_full"]
                    text: Number(card.forecast.target ?? 100) + "%"
                    description: card.estimateText
                    pixelSize: Ui.Theme.fontSizeCaption
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 2

                Ui.ThemeText {
                    text: card.powerAvailable ? (card.battery.charging ? "+" : "") + card.battery.power_watts.toFixed(1) + " W" : "— W"
                    color: card.battery.charging ? Ui.Theme.active : Ui.Theme.resourcePower
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }

                BatteryIconValue {
                    objectName: "batteryPowerDirection"
                    icons: card.battery.charging ? ["arrow_forward", "battery_full"] : ["battery_full", "arrow_forward"]
                    description: card.battery.charging ? qsTr("Power into battery") : qsTr("Power from battery")
                    visible: card.powerAvailable && (card.battery.charging || !card.battery.plugged)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            BatteryIconValue {
                Layout.fillWidth: true
                icons: [card.battery.charging ? "battery_charging_full" : (card.battery.plugged ? "power" : "battery_full")]
                text: card.exceptionalState ? Presentation.stateLabel(card.battery) : ""
                description: Presentation.stateLabel(card.battery)
                pixelSize: Ui.Theme.fontSizeCaption
            }

            Ui.SegmentedControl {
                objectName: "batteryHistoryRange"
                Layout.preferredWidth: Math.min(168, content.width * 0.55)
                options: [
                    {
                        value: "6",
                        label: "6h"
                    },
                    {
                        value: "24",
                        label: "24h"
                    },
                    {
                        value: "168",
                        label: "7d"
                    }
                ]
                value: card.range
                onSelected: function (value) {
                    card.range = value;
                }
            }
        }

        BatteryHistoryGraph {
            id: graph
            objectName: "batteryTimelineGraph"
            points: card.points
            forecast: card.forecast
            currentPercentage: card.battery.available ? Number(card.battery.percentage) : -1
            lineColor: card.battery.warning ? Ui.Theme.warning : Ui.Theme.resourceCpu
        }

        Flow {
            objectName: "batteryHistoryLegend"
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingLg

            Row {
                spacing: 5
                Rectangle {
                    width: 14
                    height: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: graph.lineColor
                }
                BatteryIconValue {
                    objectName: "batteryChargeLegend"
                    icons: ["battery_full"]
                    description: qsTr("Line: battery charge")
                }
            }
            Row {
                spacing: 5
                Rectangle {
                    width: 9
                    height: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: Ui.Theme.resourcePower
                }
                BatteryIconValue {
                    objectName: "batteryDischargingLegend"
                    icons: ["battery_full", "arrow_forward"]
                    description: qsTr("Discharging power")
                }
            }
            Row {
                spacing: 5
                Rectangle {
                    width: 9
                    height: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: Ui.Theme.active
                }
                BatteryIconValue {
                    objectName: "batteryChargingLegend"
                    icons: ["arrow_forward", "battery_full"]
                    description: qsTr("Charging power")
                }
            }

        }
    }
}
