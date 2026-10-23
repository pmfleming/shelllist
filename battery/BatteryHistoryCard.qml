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
    signal rangeRequested(int hours)
    readonly property var forecast: battery.forecast || ({
            limit: null,
            target: 100,
            seconds: 0
        })
    readonly property string estimateText: History.forecastLabel(battery)
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
            helpText: qsTr("The upper track shows observed charge in percent; its dotted extension is a forecast. The lower track shows measured power in watts: sage above zero is charging, amber below zero is discharging. Gaps are unobserved, not zero. Both tracks share observed time, excluding suspended intervals. Click either track to inspect the nearest measurement; arrows move the cursor and Escape exits inspection.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingMd

            Ui.GlyphLabel {
                glyph: card.battery.plugged ? "power" : "battery_full"
                color: Ui.Theme.batteryCharge
                font.pixelSize: Ui.Theme.iconSizeLarge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ThemeText {
                    objectName: "batteryHistoryEstimate"
                    Layout.fillWidth: true
                    text: !card.battery.available ? qsTr("Unavailable") : card.battery.plugged ? qsTr("Plugged in") : qsTr("On battery")
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightBold
                    wrapMode: Text.WordWrap
                }

                Ui.ThemeText {
                    objectName: "batteryForecastTarget"
                    Layout.fillWidth: true
                    visible: card.battery.available
                    text: card.forecast.seconds > 0 ? "~" + Presentation.duration(card.forecast.seconds) + " " + card.estimateText : card.estimateText
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                    wrapMode: Text.WordWrap
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 2

                Ui.ThemeText {
                    objectName: "batteryHistoryPower"
                    text: card.powerAvailable ? card.battery.power_watts.toFixed(1) + " W" : "— W"
                    color: !card.powerAvailable || card.battery.power_watts === 0 ? Ui.Theme.mutedText : card.battery.charging ? Ui.Theme.batteryCharging : Ui.Theme.batteryDischarging
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }

                Ui.ThemeText {
                    objectName: "batteryPowerDirection"
                    text: !card.powerAvailable ? qsTr("Unavailable") : card.battery.power_watts === 0 ? qsTr("No battery flow") : card.battery.charging ? qsTr("Into battery") : qsTr("From battery")
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                }
            }
        }

        Ui.FeedbackSource {
            text: card.exceptionalState ? Presentation.stateLabel(card.battery) : ""
            summaryText: text
        }
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Range")
            accessibleName: qsTr("Battery history range")
            Ui.SegmentedControl {
                objectName: "batteryHistoryRange"
                Layout.fillWidth: true
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
                    card.rangeRequested(Number(value));
                }
            }
        }

        BatteryHistoryGraph {
            id: graph
            objectName: "batteryTimelineGraph"
            chartData: card.history.chart || ({})
            forecast: card.forecast
            currentPercentage: card.battery.available && History.nonnegative(card.battery.percentage) && card.battery.percentage <= 100 ? card.battery.percentage : -1
            lineColor: card.battery.warning ? Ui.Theme.warning : Ui.Theme.batteryCharge
        }

        // Battery-owned chart keys: tiny 2px corners distinguish filled swatches
        // from line marks without introducing another control/card radius.
        Flow {
            objectName: "batteryHistoryLegend"
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingLg

            Row {
                spacing: Ui.Theme.spacingSm
                Rectangle {
                    width: Ui.Theme.spacingSm
                    height: width
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: graph.chargingColor
                }
                Ui.ThemeText {
                    objectName: "batteryChargingLegend"
                    text: qsTr("Charging")
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                }
            }
            Row {
                spacing: Ui.Theme.spacingSm
                Rectangle {
                    width: Ui.Theme.spacingSm
                    height: width
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: graph.dischargingColor
                }
                Ui.ThemeText {
                    objectName: "batteryDischargingLegend"
                    text: qsTr("Discharging")
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                }
            }
        }
        Ui.FeedbackSource {
            objectName: "batteryHistoryInspection"
            text: graph.cursorPosition >= 0 ? graph.inspectionText : qsTr("Observed time · suspended intervals excluded")
            summaryText: graph.cursorPosition >= 0 ? graph.inspectionSummary : text
            briefText: graph.cursorPosition >= 0 ? (graph.historicalPosition > 1 ? graph.inspectionText : graph.inspectionReading) : qsTr("Suspended time excluded")
            priority: graph.cursorPosition >= 0 ? 5 : 0
        }
    }
}
