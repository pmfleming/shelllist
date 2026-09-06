pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Ui.DetailColumnCard {
    id: card

    required property var history
    required property var battery

    readonly property var forecast: History.chargeForecast(battery)
    readonly property real historyFraction: forecast.seconds > 0
        ? Math.max(60000, chargeGraph.series.activeDurationMs)
            / (Math.max(60000, chargeGraph.series.activeDurationMs) + forecast.seconds * 1000) : 1
    readonly property real axisWidth: Math.max(40, chargeGraph.scaleWidth, energyGraph.scaleWidth)
    property real hoverPosition: -1
    readonly property real historicalPosition: hoverPosition / historyFraction
    readonly property var hoveredSample: hoverPosition >= 0 && historicalPosition <= 1
        ? History.nearestSample(chargeGraph.series.segments, historicalPosition) : null
    readonly property var hoveredEnergy: hoverPosition >= 0 && historicalPosition <= 1
        ? energyGraph.energySeries.bars.find(function (bar) {
            return card.historicalPosition >= bar.x0 && card.historicalPosition <= bar.x1;
        }) : null
    readonly property string estimateText: forecast.seconds > 0
        ? "~" + Presentation.duration(forecast.seconds) + " to " + forecast.target + "%"
            + (forecast.limit !== null ? " limit" : " full")
        : (forecast.estimating ? "Estimating charge time…"
            : (battery.available && forecast.limit !== null && battery.percentage >= forecast.target
                ? "Charge limit reached" : ""))

    title: "Battery history · 7 days"
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding

    Ui.FieldLabel {
        objectName: "batteryHistoryStatus"
        Layout.fillWidth: true
        text: card.battery.available
            ? Math.round(Number(card.battery.percentage) || 0) + "% · " + Presentation.stateLabel(card.battery)
            : "Unavailable"
        color: card.battery.warning ? Ui.Theme.warning : Ui.Theme.accent
    }

    Ui.FieldLabel {
        objectName: "batteryHistoryEstimate"
        Layout.fillWidth: true
        visible: text.length > 0
        text: card.estimateText
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: Presentation.historyRange(card.history) + " · " + History.activeDuration(card.history.points || [])
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    BatteryHistoryGraph {
        id: chargeGraph
        objectName: "chargeHistoryGraph"
        points: card.history.points || []
        label: "Charge level"
        valueText: card.forecast.seconds > 0 ? "Dotted: estimate" : ""
        lineColor: card.battery.warning ? Ui.Theme.warning : Ui.Theme.accent
        forecast: card.forecast
        currentPercentage: card.battery.available ? Number(card.battery.percentage) : -1
        historyFraction: card.historyFraction
        axisWidth: card.axisWidth
        hoverPosition: card.hoverPosition
        onHovered: function (position) { card.hoverPosition = position; }
    }

    BatteryHistoryGraph {
        id: energyGraph
        objectName: "energyHistoryGraph"
        points: card.history.points || []
        energy: true
        label: "Battery energy used · Wh"
        valueText: "~" + energySeries.totalWh.toFixed(2) + " Wh"
        lineColor: Ui.Theme.accent
        historyFraction: card.historyFraction
        axisWidth: card.axisWidth
        hoverPosition: card.hoverPosition
        showTimeAxis: true
        onHovered: function (position) { card.hoverPosition = position; }
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: "Estimated from discharge power · "
            + Presentation.duration(energyGraph.energySeries.intervalMs / 1000)
            + " observed-time bins; gaps excluded"
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    Ui.FieldLabel {
        objectName: "batteryHistoryHover"
        Layout.fillWidth: true
        // Keep both tracks stationary when the shared readout changes.
        Layout.minimumHeight: font.pixelSize * 3
        text: card.hoverPosition < 0 ? "Hover either track to inspect charge and energy."
            : (card.historicalPosition > 1 ? "Projected charge · " + card.estimateText
                : ((card.hoveredSample
                    ? new Date(card.hoveredSample.timestamp_ms).toLocaleString()
                        + " · " + Math.round(card.hoveredSample.value) + "% (nearest sample)"
                    : "No charge sample")
                    + "\n" + (card.hoveredEnergy
                        ? "~" + card.hoveredEnergy.value.toFixed(2) + " Wh · "
                            + Presentation.duration(card.hoveredEnergy.observedMs / 1000) + " sampled in bin"
                        : "No discharge energy sampled here")))
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
