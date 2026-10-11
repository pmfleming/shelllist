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
    readonly property string memorySource: application.running ? Resources.text((application.measurement || {}).memory_source, "unknown") : qsTr("Source not recorded")
    readonly property string observationStatus: application.running ? ""
        : latestPoint ? qsTr("App stopped · last observed %1").arg(Qt.formatDateTime(new Date(latestPoint.timestamp_ms), "yyyy-MM-dd HH:mm:ss")) : qsTr("App stopped · no retained measurements")
    readonly property var lanes: [
        lane("activity", qsTr("Activity"), "percent", [
            series("cpu_percent_of_machine", "CPU", "CPU", "memory", Ui.Theme.applicationGraphColors.activity[0], "percent", "applicationCpuActivity", 0),
            series("gpu_busy_percent", qsTr("GPU activity"), "GPU", "developer_board", Ui.Theme.applicationGraphColors.activity[1], "percent", "applicationGpuActivity", 0)]),
        lane("memory", qsTr("Memory"), "bytes", [
            series("memory_bytes", "RAM", "RAM", "memory_alt", Ui.Theme.applicationGraphColors.memory[0], "bytes", "applicationRam", 0),
            series("gpu_memory_resident_bytes", qsTr("GPU resident memory"), "GPU", "developer_board", Ui.Theme.applicationGraphColors.memory[1], "bytes", "applicationGpuMemory", 0)]),
        lane("storage", qsTr("Disk I/O"), "rate", [
            series("disk_read_bytes_per_second", qsTr("Disk read"), qsTr("↓ Read"), "arrow_downward", Ui.Theme.applicationGraphColors.storage[0], "rate", "applicationIo_disk_read_bytes_per_second", 1),
            series("disk_write_bytes_per_second", qsTr("Disk write"), qsTr("↑ Written"), "arrow_upward", Ui.Theme.applicationGraphColors.storage[1], "rate", "applicationIo_disk_write_bytes_per_second", -1)]),
        lane("network", qsTr("Network"), "rate", [
            series("network_receive_bytes_per_second", qsTr("Network receive"), qsTr("↓ Received"), "arrow_downward", Ui.Theme.applicationGraphColors.network[0], "rate", "applicationIo_network_receive_bytes_per_second", 1),
            series("network_transmit_bytes_per_second", qsTr("Network send"), qsTr("↑ Sent"), "arrow_upward", Ui.Theme.applicationGraphColors.network[1], "rate", "applicationIo_network_transmit_bytes_per_second", -1)]),
        lane("energy", qsTr("CPU-package energy"), "power", [
            series("average_power_watts", application.running ? qsTr("Estimated CPU-package power") : qsTr("Last observed CPU-package power"), qsTr("Estimated"), "bolt", Ui.Theme.applicationGraphColors.energy[0], "power", "applicationPower", 0)])
    ]

    function currentHas(metric: string): bool {
        return application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(latestPoint, metric);
    }
    function currentText(metric: string, kind: string): string {
        return currentHas(metric) ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : current[metric], kind) : qsTr("Unavailable");
    }
    function series(metric: string, label: string, shortLabel: string, icon: string, color: color, kind: string, objectName: string, direction: int): var {
        const stats = Resources.summaryMetric(summary, metric);
        const periodValue = controller.historyInFlight ? null : Resources.periodEstimate(summary, metric);
        let detail = qsTr("Average %1 · Peak %2 · %3").arg(Resources.formatted(stats.mean, kind)).arg(Resources.formatted(stats.peak, kind)).arg(Resources.observationText(summary, metric));
        if (metric === "cpu_percent_of_machine") detail += qsTr(". Percent of total-machine capacity.");
        if (metric === "gpu_busy_percent") detail += qsTr(". Engine activity; not summed with CPU.");
        if (metric === "memory_bytes") detail += qsTr(". RAM source: %1").arg(memorySource);
        if (kind === "power") detail += qsTr(". RAPL CPU-package attribution; confidence %1; period confidence %2.")
            .arg(Resources.text(current.energy_confidence, "unknown")).arg(Resources.rangeEnergyConfidence(summary));
        if (kind === "rate" || kind === "power") detail += qsTr(". %1: %2").arg(controller.historyRange).arg(controller.historyInFlight ? qsTr("Loading…") : Resources.periodText(summary, metric));
        return {metric: metric, label: label, shortLabel: shortLabel, icon: icon, color: color, kind: kind, objectName: objectName, direction: direction,
            available: currentHas(metric), valueText: currentText(metric, kind), mean: stats.mean, peak: stats.peak, detailText: detail,
            periodValue: periodValue, periodText: controller.historyInFlight ? qsTr("Loading…") : Resources.periodText(summary, metric),
            observation: Resources.observationText(summary, metric), observedMs: stats.observed_ms, coverage: Resources.compactObservation(summary, metric)};
    }
    function lane(id: string, label: string, kind: string, descriptors: var): var {
        const coverageEqual = descriptors.every(descriptor => descriptor.observedMs === descriptors[0].observedMs);
        const coverage = coverageEqual ? descriptors[0].coverage : descriptors.map(descriptor => descriptor.shortLabel + " " + descriptor.coverage).join(" · ");
        return {id: id, label: label, kind: kind, series: descriptors, rangeLabel: controller.historyRange, coverageText: coverage,
            accessibleText: label + ". " + descriptors.map(descriptor => descriptor.label + ": " + descriptor.valueText + ". " + descriptor.detailText).join(". ")};
    }

    Layout.fillWidth: true
    spacing: Math.round(6 * uiScale)

    Ui.FeedbackSource {
        objectName: "applicationResourceSnapshotStatus"
        active: history.observationStatus.length > 0
        text: history.observationStatus
        summaryText: history.latestPoint ? qsTr("App stopped · Last observation") : qsTr("App stopped · No measurements")
    }
    Ui.FormField {
        Layout.fillWidth: true
        accessibleName: qsTr("Resource history range")
        Ui.SegmentedControl {
            objectName: "applicationHistoryRange"
            Layout.preferredWidth: Math.min(history.width, Ui.Theme.fieldLabelWidth(history.width) * 2)
            options: [{value: "30m", label: "30m"}, {value: "2h", label: "2h"}, {value: "24h", label: "24h"}]
            value: history.controller.historyRange
            onSelected: function (value) { history.controller.selectHistoryRange(value); }
        }
    }
    ApplicationResourceOverview {
        id: overview
        objectName: "applicationResourceOverview"
        Layout.fillWidth: true
        Layout.fillHeight: true
        lanes: history.lanes
        points: history.points
        loading: history.controller.historyInFlight
        active: history.controller.uiActive
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        uiScale: history.uiScale
    }
    ApplicationResourceTimeAxis {
        objectName: "applicationResourceTimeAxis"
        Layout.fillWidth: true
        Layout.leftMargin: overview.plotLeftInset
        Layout.rightMargin: overview.contentPadding
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
    }
    Ui.FeedbackSource {
        objectName: "applicationProcessCoverage"
        readonly property var coverage: history.application.running ? (history.application.measurement || {}).coverage : history.current.coverage
        readonly property bool shared: !!(history.application.measurement || {}).resources_shared && history.application.running
        active: !Resources.measured(coverage) || coverage < 1 || shared
        text: (Resources.measured(coverage) ? qsTr("Process coverage %1").arg(Resources.ratioPercent(coverage)) : qsTr("Unknown process coverage"))
            + (shared ? qsTr(" · Shared attribution") : "")
        summaryText: shared ? qsTr("Shared resource attribution") : qsTr("Partial process coverage")
        tone: "warning"
    }
    Ui.FeedbackSource {
        objectName: "applicationSwapStatus"
        active: history.currentHas("memory_swap_bytes") && history.current.memory_swap_bytes > 0
        text: qsTr("Swap %1").arg(history.currentText("memory_swap_bytes", "bytes"))
    }
}
