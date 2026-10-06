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
    property bool detailsExpanded: false
    signal revealDetails(Item item)
    readonly property string applicationId: application.id || ""
    readonly property var points: controller.resourceHistory || []
    readonly property var latestPoint: points.length > 0 ? points[points.length - 1] : null
    readonly property var current: application.running ? application : latestPoint || ({})
    readonly property var summary: Resources.windowSummary(controller.resourceHistorySummary, controller.historyWindowStartMs, controller.historyWindowEndMs)
    readonly property string rangeLabel: controller.historyRange
    readonly property string memorySource: application.running ? Resources.text((application.measurement || {}).memory_source, "unknown").toUpperCase() : qsTr("Source not recorded")
    readonly property string periodConfidence: Resources.rangeEnergyConfidence(points)
    readonly property string currentConfidence: Resources.text(current.energy_confidence, "unknown").toLowerCase()
    readonly property string energyQualifier: currentHas("average_power_watts")
        ? qsTr("RAPL · %1 confidence").arg(currentConfidence) + (currentConfidence !== periodConfidence ? qsTr(" · period %1").arg(periodConfidence) : "")
        : points.some(point => Resources.historicalMetricAvailable(point, "average_power_watts")) ? qsTr("RAPL history · %1 confidence").arg(periodConfidence) : qsTr("Attribution unavailable")
    readonly property string observationStatus: application.running ? qsTr("Latest snapshot")
        : latestPoint ? qsTr("App stopped · last observed %1").arg(Qt.formatDateTime(new Date(latestPoint.timestamp_ms), "yyyy-MM-dd HH:mm:ss")) : qsTr("App stopped · no retained measurements")
    readonly property var footprint: ({
        available: currentHas("disk_space_total_bytes"), valueText: currentText("disk_space_total_bytes", "bytes"),
        permanent: Number(current.disk_space_permanent_bytes) || 0, temporary: Number(current.disk_space_temporary_bytes) || 0,
        compositionAvailable: currentHas("disk_space_total_bytes") && currentHas("disk_space_permanent_bytes") && currentHas("disk_space_temporary_bytes"),
        detailText: qsTr("Persistent: %1 · Temporary: %2. Installation and shared dependencies not measured. Composition, not disk capacity; temporary does not mean safe to delete.").arg(currentText("disk_space_permanent_bytes", "bytes")).arg(currentText("disk_space_temporary_bytes", "bytes"))
    })
    readonly property var lanes: [
        lane("activity", qsTr("Activity"), "equalizer", qsTr("CPU · machine / GPU · engine"), "percent", "lines", [
            series("cpu_percent_of_machine", "CPU", "CPU", Ui.Theme.resourceCpu, "percent", "applicationCpuActivity", 0, false),
            series("gpu_busy_percent", qsTr("GPU activity"), "GPU", Ui.Theme.resourceGpu, "percent", "applicationGpuActivity", 0, true)]),
        lane("memory", qsTr("Memory"), "memory", memorySource + qsTr(" · GPU resident")
            + (currentHas("memory_swap_bytes") && Number(current.memory_swap_bytes) > 0 ? qsTr(" · Swap %1").arg(currentText("memory_swap_bytes", "bytes")) : ""), "bytes", "steps", [
            series("memory_bytes", "RAM", "RAM", Ui.Theme.resourceMemory, "bytes", "applicationRam", 0, false),
            series("gpu_memory_resident_bytes", qsTr("GPU resident memory"), "GPU", Ui.Theme.resourceGpu, "bytes", "applicationGpuMemory", 0, true)]),
        lane("storage", qsTr("Storage"), "storage", qsTr("↓ read / ↑ write"), "rate", "columns", [
            series("disk_read_bytes_per_second", qsTr("Disk read"), "↓ R", Ui.Theme.resourceDisk, "rate", "applicationIo_disk_read_bytes_per_second", 1, false),
            series("disk_write_bytes_per_second", qsTr("Disk write"), "↑ W", Ui.Theme.resourceNetworkTransmit, "rate", "applicationIo_disk_write_bytes_per_second", -1, false)]),
        lane("network", qsTr("Network"), "󰈀", qsTr("↓ receive / ↑ send"), "rate", "paired-area", [
            series("network_receive_bytes_per_second", qsTr("Network receive"), "↓", Ui.Theme.resourceNetworkReceive, "rate", "applicationIo_network_receive_bytes_per_second", 1, false),
            series("network_transmit_bytes_per_second", qsTr("Network send"), "↑", Ui.Theme.resourceNetworkTransmit, "rate", "applicationIo_network_transmit_bytes_per_second", -1, false)]),
        lane("energy", qsTr("CPU-package energy"), "bolt", energyQualifier, "power", "area", [
            series("average_power_watts", application.running ? qsTr("Estimated power") : qsTr("Last observed power"), "", Ui.Theme.resourcePower, "power", "applicationPower", 0, false)])
    ]

    function currentHas(metric: string): bool {
        return application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(latestPoint, metric);
    }
    function currentText(metric: string, kind: string): string {
        return currentHas(metric) ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : current[metric], kind) : qsTr("Unavailable");
    }
    function series(metric: string, label: string, shortLabel: string, color: color, kind: string, objectName: string, direction: int, dashed: bool): var {
        const stats = Resources.summaryMetric(summary, metric);
        const detail = qsTr("Average %1 · Peak %2 · %3").arg(Resources.formatted(stats.mean, kind)).arg(Resources.formatted(stats.peak, kind)).arg(Resources.observationText(summary, metric));
        return {metric: metric, label: label, shortLabel: shortLabel, color: color, kind: kind, objectName: objectName, direction: direction, dashed: dashed,
            available: currentHas(metric), valueText: currentText(metric, kind), mean: stats.mean, peak: stats.peak, detailText: detail,
            observation: Resources.observationText(summary, metric), observedMs: stats.observed_ms, coverage: Resources.compactObservation(summary, metric)};
    }
    function lane(id: string, label: string, icon: string, qualifier: string, kind: string, style: string, descriptors: var): var {
        const missing = descriptors.filter(descriptor => !descriptor.available).map(descriptor => descriptor.label).join(" / ");
        const coverageEqual = descriptors.every(descriptor => descriptor.observedMs === descriptors[0].observedMs);
        const coverage = coverageEqual ? descriptors[0].coverage : descriptors.map(descriptor => descriptor.shortLabel + " " + descriptor.coverage).join(" · ");
        const period = descriptors.map(descriptor => (descriptors.length > 1 ? descriptor.shortLabel + " " : "") + Resources.periodText(summary, descriptor.metric)).join(" · ");
        const unavailable = missing ? qsTr("%1 unavailable").arg(missing) + (id === "network" ? qsTr(" · byte attribution unavailable; not zero traffic") : "") : "";
        return {id: id, label: label, icon: icon, qualifier: qualifier, kind: kind, style: style, series: descriptors,
            rangeLabel: rangeLabel, coverageText: coverage, unavailableText: unavailable,
            periodText: controller.historyInFlight ? qsTr("Loading…") : period,
            periodAvailable: Resources.periodEstimate(summary, descriptors[0].metric) !== null,
            accessibleText: label + ". " + qualifier + ". " + descriptors.map(descriptor => descriptor.label + ": " + descriptor.valueText + ". " + descriptor.detailText).join(". ")
                + (kind === "rate" || kind === "power" ? qsTr(". Estimated totals over %1: %2").arg(rangeLabel).arg(controller.historyInFlight ? qsTr("Loading…") : period) : "") + ". " + unavailable};
    }
    function toggleDetails(): void {
        detailsExpanded = !detailsExpanded;
        if (detailsExpanded) Qt.callLater(function () { history.revealDetails(measurements.revealTarget); });
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingSm * uiScale)
    onApplicationIdChanged: detailsExpanded = false

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            objectName: "applicationResourceSnapshotStatus"
            Layout.fillWidth: true
            text: history.observationStatus
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        Ui.SegmentedControl {
            objectName: "applicationHistoryRange"
            Layout.preferredWidth: Math.round(170 * history.uiScale)
            Layout.preferredHeight: Math.round(36 * history.uiScale)
            options: [{value: "30m", label: "30m"}, {value: "2h", label: "2h"}, {value: "24h", label: "24h"}]
            value: history.controller.historyRange
            onSelected: function (value) { history.controller.selectHistoryRange(value); }
        }
    }
    Ui.DetailSection {
        Layout.fillWidth: true
        informationOnly: true
        ApplicationResourceLaneChart {
            objectName: "applicationResourceTimeline"
            Layout.fillWidth: true
            points: history.points
            lanes: history.lanes
            footprint: history.footprint
            loading: history.controller.historyInFlight
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            uiScale: history.uiScale
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.ThemeText {
            objectName: "applicationProcessCoverage"
            Layout.fillWidth: true
            text: {
                const coverage = history.application.running ? (history.application.measurement || {}).coverage : history.current.coverage;
                return (Resources.measured(coverage) ? qsTr("Process coverage %1").arg(Resources.ratioPercent(coverage)) : qsTr("Unknown process coverage"))
                    + ((history.application.measurement || {}).resources_shared && history.application.running ? qsTr(" · Shared attribution") : "");
            }
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
            wrapMode: Text.Wrap
        }
        Ui.CommandGroup {
            Layout.preferredWidth: detailsButton.implicitWidth
            Layout.preferredHeight: detailsButton.implicitHeight
            Ui.FlatIconButton {
                id: detailsButton
                objectName: "applicationMeasurementDetailsCommand"
                sizeRole: "secondary"
                uiScale: history.uiScale * 2 / 3
                icon: "info"
                accessKey: "H"
                accessibleName: history.detailsExpanded ? qsTr("Hide measurement details") : qsTr("Show measurement details")
                onClicked: history.toggleDetails()
            }
            // The named menu includes unassigned commands; this presentation
            // invokes the same read-only disclosure as the Alt+H icon.
            Ui.ActionControl {
                objectName: "applicationMeasurementDetailsMenuCommand"
                width: 0
                height: 0
                activeFocusOnTab: false
                Accessible.ignored: true
                accessibleName: detailsButton.accessibleName
                onClicked: history.toggleDetails()
            }
        }
    }
    ApplicationResourceOverview {
        id: measurements
        objectName: "applicationMeasurementDetails"
        Layout.fillWidth: true
        visible: history.detailsExpanded
        application: history.application
        latestPoint: history.latestPoint
        lanes: history.lanes
        footprint: history.footprint
        memorySource: history.memorySource
        swapText: history.currentText("memory_swap_bytes", "bytes")
        allocatedText: history.currentText("gpu_memory_allocated_bytes", "bytes")
        referencedText: qsTr("Referenced files: %1 · temporary: %2. May overlap app data or be shared; not added to the total.").arg(history.currentText("referenced_file_disk_bytes", "bytes")).arg(history.currentText("referenced_file_temporary_bytes", "bytes"))
        uiScale: history.uiScale
    }
}
