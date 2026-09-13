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

    readonly property var forecast: History.chargeForecast(battery)
    readonly property real historyFraction: forecast.seconds > 0 ? Math.max(60000, chargeGraph.series.activeDurationMs) / (Math.max(60000, chargeGraph.series.activeDurationMs) + forecast.seconds * 1000) : 1
    // Match the application resource timeline's 150px label rail, including padding.
    readonly property real axisWidth: Math.min(138, Math.max(96, content.width * 0.36))
    property int contentSpacing: Ui.Theme.spacingSm
    property real hoverPosition: -1
    readonly property real historicalPosition: hoverPosition / historyFraction
    readonly property var hoveredSample: hoverPosition >= 0 && historicalPosition <= 1 ? History.nearestSample(chargeGraph.series.segments, historicalPosition) : null
    readonly property var hoveredEnergy: hoverPosition >= 0 && historicalPosition <= 1 ? energyGraph.energySeries.bars.find(function (bar) {
        return card.historicalPosition >= bar.x0 && card.historicalPosition <= bar.x1;
    }) : null
    readonly property string estimateText: forecast.seconds > 0 ? "~" + Presentation.duration(forecast.seconds) + " to " + forecast.target + "%" + (forecast.limit !== null ? " limit" : " full") : (forecast.estimating ? "Estimating charge time…" : (battery.available && forecast.limit !== null && battery.percentage >= forecast.target ? "Charge limit reached" : ""))

    width: parent ? parent.width : 0
    implicitHeight: content.implicitHeight + 2 * Ui.Theme.spacingMd
    height: implicitHeight
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.7)
    border.width: 0

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: card.contentSpacing

        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Battery history · 7 days")
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
            elide: Text.ElideRight
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: Presentation.historyRange(card.history) + " · " + History.activeDuration(card.history.points || [])
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Ui.FieldLabel {
            objectName: "batteryHistoryEstimate"
            Layout.fillWidth: true
            visible: text.length > 0
            text: card.estimateText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        BatteryHistoryGraph {
            id: chargeGraph
            objectName: "chargeHistoryGraph"
            points: card.history.points || []
            label: qsTr("Charge level")
            valueText: card.battery.available ? Math.round(Number(card.battery.percentage) || 0) + "%" : qsTr("Unavailable")
            referenceText: Presentation.stateLabel(card.battery)
            lineColor: card.battery.warning ? Ui.Theme.warning : Ui.Theme.resourceCpu
            forecast: card.forecast
            currentPercentage: card.battery.available ? Number(card.battery.percentage) : -1
            historyFraction: card.historyFraction
            axisWidth: card.axisWidth
            hoverPosition: card.hoverPosition
            onHovered: function (position) {
                card.hoverPosition = position;
            }
        }

        BatteryHistoryGraph {
            id: energyGraph
            objectName: "energyHistoryGraph"
            points: card.history.points || []
            energy: true
            label: qsTr("Energy used")
            valueText: energySeries.bars.length > 0 ? "~" + energySeries.totalWh.toFixed(2) + " Wh" : qsTr("Unavailable")
            referenceText: energySeries.bars.length > 0 ? "max " + maximum.toFixed(1) + " Wh/bin" : qsTr("No measurements")
            lineColor: Ui.Theme.resourcePower
            historyFraction: card.historyFraction
            axisWidth: card.axisWidth
            hoverPosition: card.hoverPosition
            showTimeAxis: true
            onHovered: function (position) {
                card.hoverPosition = position;
            }
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: "Estimated from discharge power · " + Presentation.duration(energyGraph.energySeries.intervalMs / 1000) + " observed-time bins; gaps excluded"
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Ui.FieldLabel {
            objectName: "batteryHistoryHover"
            Layout.fillWidth: true
            // Keep both tracks stationary when the shared readout changes.
            Layout.minimumHeight: font.pixelSize * 3
            text: card.hoverPosition < 0 ? "Hover either track to inspect charge and energy." : (card.historicalPosition > 1 ? "Projected charge · " + card.estimateText : ((card.hoveredSample ? new Date(card.hoveredSample.timestamp_ms).toLocaleString() + " · " + Math.round(card.hoveredSample.value) + "% (nearest sample)" : "No charge sample") + "\n" + (card.hoveredEnergy ? "~" + card.hoveredEnergy.value.toFixed(2) + " Wh · " + Presentation.duration(card.hoveredEnergy.observedMs / 1000) + " sampled in bin" : "No discharge energy sampled here")))
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
