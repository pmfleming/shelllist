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

    title: "Battery history · 7 days"
    // Size from the actual heading, labels and plots, not a fixed estimate.
    // Fixed padding keeps the content-driven height independent of density.
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: Presentation.historyRange(card.history)
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: History.activeDuration(card.history.points || [])
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    BatteryHistoryGraph {
        objectName: "chargeHistoryGraph"
        points: card.history.points || []
        metric: "percentage"
        label: "Charge level"
        valueText: card.battery.available
            ? "Now " + Math.round(Number(card.battery.percentage) || 0) + "%" : "Unavailable"
        lineColor: card.battery.warning ? Ui.Theme.warning : Ui.Theme.accent
        minimumMaximum: 100
    }

    BatteryHistoryGraph {
        objectName: "fullHistoryGraph"
        points: card.history.points || []
        metric: "time_to_full_seconds"
        label: "Estimated time until full"
        valueText: card.battery.charging
            ? "Now " + Presentation.duration(card.battery.time_to_full_seconds) : "Not charging"
        lineColor: Ui.Theme.active
        minimumMaximum: 3600
        positiveOnly: true
    }
}
