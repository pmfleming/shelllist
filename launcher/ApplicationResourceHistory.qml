pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

ColumnLayout {
    id: history

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var points: controller.resourceHistory || []
    readonly property var latestPoint: points.length > 0 ? points[points.length - 1] : null
    readonly property var current: application.running ? application : latestPoint || ({})
    readonly property var summary: Resources.windowSummary(controller.resourceHistorySummary, controller.historyWindowStartMs, controller.historyWindowEndMs)
    readonly property string rangeLabel: controller.historyRange === "24h" ? qsTr("last 24 hours") : controller.historyRange === "2h" ? qsTr("last 2 hours") : qsTr("last 30 minutes")

    function currentHas(metric: string): bool {
        return application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(latestPoint, metric);
    }
    function currentText(metric: string, kind: string): string {
        return currentHas(metric) ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : current[metric], kind) : qsTr("Unavailable");
    }
    function statistic(metric: string, field: string, kind: string): string {
        return Resources.formatted(Resources.summaryMetric(summary, metric)[field], kind);
    }
    function graphSeries(metric: string, label: string, color: color, kind: string, direction: int): var {
        return {metric: metric, label: label, color: color, kind: kind, direction: direction};
    }
    function lane(label: string, kind: string, series: var): var {
        const available = series.some(function (descriptor) {
            return points.some(function (point) { return Resources.historicalMetricAvailable(point, descriptor.metric); });
        });
        return {
            label: label,
            valueText: series.map(function (descriptor) { return (series.length > 1 ? descriptor.label + " " : "") + currentText(descriptor.metric, kind); }).join("\n"),
            averageText: series.map(function (descriptor) { return (series.length > 1 ? descriptor.label + " " : "") + statistic(descriptor.metric, "mean", kind); }).join("\n"),
            peakText: series.map(function (descriptor) { return (series.length > 1 ? descriptor.label + " " : "") + statistic(descriptor.metric, "peak", kind); }).join("\n"),
            observationText: series.map(function (descriptor) { return (series.length > 1 ? descriptor.label + " " : "") + Resources.observationText(summary, descriptor.metric); }).join("\n"),
            color: series[0].color,
            kind: kind,
            unavailable: !available,
            chartStyle: series.length > 1 ? "paired" : "area",
            series: series
        };
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingMd
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Period totals & history")
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeLabel
        }
        Ui.SegmentedControl {
            objectName: "applicationHistoryRange"
            Layout.preferredWidth: Math.round(180 * history.uiScale)
            Layout.preferredHeight: Math.round(36 * history.uiScale)
            options: [{value: "30m", label: "30m"}, {value: "2h", label: "2h"}, {value: "24h", label: "24h"}]
            value: history.controller.historyRange
            onSelected: function (value) { history.controller.selectHistoryRange(value); }
        }
    }

    ApplicationResourceOverview {
        Layout.fillWidth: true
        application: history.application
        latestPoint: history.latestPoint
        summary: history.summary
        rangeLabel: history.rangeLabel
        periodEnergyConfidence: Resources.rangeEnergyConfidence(history.points)
        historyLoading: history.controller.historyInFlight
        uiScale: history.uiScale
    }

    Ui.DetailSection {
        Layout.fillWidth: true
        informationOnly: true
        ApplicationResourceLaneChart {
            objectName: "applicationResourceTimeline"
            Layout.fillWidth: true
            title: qsTr("Resource history · %1").arg(history.rangeLabel)
            points: history.points
            summaries: history.summary ? history.summary.metrics : ({})
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            maximumGapMilliseconds: Math.max(30000, (rangeEndMilliseconds - rangeStartMilliseconds) / 500)
            uiScale: history.uiScale
            lanes: [
                history.lane(qsTr("CPU · machine capacity"), "percent", [history.graphSeries("cpu_percent_of_machine", "CPU", Ui.Theme.resourceCpu, "percent", 0)]),
                history.lane(qsTr("RAM"), "bytes", [history.graphSeries("memory_bytes", "RAM", Ui.Theme.resourceMemory, "bytes", 0)]),
                history.lane(qsTr("GPU · engine busy"), "percent", [history.graphSeries("gpu_busy_percent", "GPU", Ui.Theme.resourceGpu, "percent", 0)]),
                history.lane(qsTr("Disk I/O"), "rate", [history.graphSeries("disk_read_bytes_per_second", qsTr("Read"), Ui.Theme.resourceDisk, "rate", 1), history.graphSeries("disk_write_bytes_per_second", qsTr("Write"), Ui.Theme.resourceNetworkTransmit, "rate", -1)]),
                history.lane(qsTr("Network"), "rate", [history.graphSeries("network_receive_bytes_per_second", qsTr("Receive"), Ui.Theme.resourceNetworkReceive, "rate", 1), history.graphSeries("network_transmit_bytes_per_second", qsTr("Send"), Ui.Theme.resourceNetworkTransmit, "rate", -1)]),
                history.lane(qsTr("Power · estimated\n%1 confidence").arg(Resources.rangeEnergyConfidence(history.points)), "power", [history.graphSeries("average_power_watts", "Power", Ui.Theme.resourcePower, "power", 0)])
            ]
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Individual y-scales; heights are not comparable across resources. Paired lanes: read/receive above zero, write/send below. Averages use observed time only; shaded gaps are missing measurements, not zeroes. Power is attributed CPU-package power, not whole-system electricity.")
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
}
