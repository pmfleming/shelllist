pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation
import "ApplicationResources.js" as Resources

ColumnLayout {
    id: history

    required property ApplicationController controller
    required property var application
    required property real uiScale

    readonly property var points: controller.resourceHistory || []
    readonly property var latestPoint: points.length > 0 ? points[points.length - 1] : ({})
    readonly property var current: application.running ? application : latestPoint
    readonly property bool cpuAvailable: currentHas("cpu_percent_of_machine")
    readonly property bool memoryAvailable: currentHas("memory_bytes")
    readonly property bool gpuAvailable: currentHas("gpu_busy_percent")
    readonly property bool storageAvailable: currentHas("disk_read_bytes_per_second")
    readonly property bool diskSpaceAvailable: currentHas("disk_space_total_bytes")
    readonly property bool referencedFilesAvailable: currentHas("referenced_file_disk_bytes")
    readonly property bool networkBytesAvailable: currentHas("network_receive_bytes_per_second")
    readonly property bool energyAvailable: currentHas("average_power_watts")
    readonly property real energyFraction: Math.max(0, Math.min(1, Number(current.attributed_fraction || 0)))

    readonly property color cpuColor: Ui.Theme.resourceCpu
    readonly property color memoryColor: Ui.Theme.resourceMemory
    readonly property color gpuColor: Ui.Theme.resourceGpu
    readonly property color diskColor: Ui.Theme.resourceDisk
    readonly property color networkReceiveColor: Ui.Theme.resourceNetworkReceive
    readonly property color networkTransmitColor: Ui.Theme.resourceNetworkTransmit
    readonly property color powerColor: Ui.Theme.resourcePower

    function currentHas(metric: string): bool {
        return application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(latestPoint, metric);
    }
    function metricSummary(metric: string): var {
        const summary = controller.resourceHistorySummary;
        return summary && summary.metrics ? (summary.metrics[metric] || {}) : {};
    }
    function historyHas(metric: string): bool {
        return metricSummary(metric).available === true;
    }
    function currentPower(): var {
        return application.running ? application.estimated_app_power_watts || application.power_watts : latestPoint.average_power_watts;
    }
    function average(metric: string): real {
        return Number(metricSummary(metric).mean || 0);
    }
    function peak(metric: string, nested: bool): real {
        return Number(metricSummary(metric === "estimated_app_power_watts" ? "average_power_watts" : metric).peak || 0);
    }
    function formatted(value: var, kind: string): string {
        if (kind === "bytes")
            return Resources.bytes(value);
        if (kind === "rate")
            return Resources.rate(value);
        if (kind === "power")
            return Resources.power(value);
        return Resources.percent(value);
    }
    function reference(metric: string, peakMetric: string, kind: string): string {
        if (!historyHas(metric))
            return qsTr("No measurements");
        return "avg " + formatted(average(metric), kind) + " · peak " + formatted(peak(metric, false), kind);
    }
    function graphSeries(metric: string, peakMetric: string, label: string, color: color, kind: string, direction: int): var {
        return {
            metric: metric,
            peakMetric: peakMetric || "",
            label: label,
            color: color,
            kind: kind,
            direction: direction || 0
        };
    }
    function lane(label: string, valueText: string, secondaryText: string, referenceText: string, color: color, maximum: real, unavailable: bool, chartStyle: string, series: var): var {
        return {
            label: label,
            valueText: valueText,
            secondaryText: secondaryText,
            referenceText: referenceText,
            color: color,
            maximum: maximum,
            currentUnavailable: unavailable,
            unavailable: !series.some(function (descriptor) {
                return historyHas(descriptor.metric);
            }),
            chartStyle: chartStyle,
            series: series
        };
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        Layout.fillWidth: true
        text: qsTr("Resource composition")
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Math.round(Ui.Theme.spacingSm * history.uiScale)
        rowSpacing: 0

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "Application data"
            valueText: Resources.bytes(history.current.disk_space_total_bytes)
            detailText: Resources.bytes(history.current.disk_space_permanent_bytes) + " permanent"
            accentColor: history.cpuColor
            maximum: Math.max(1, Number(history.current.disk_space_total_bytes || 0))
            uiScale: history.uiScale
            available: history.diskSpaceAvailable
            segments: [
                {
                    value: history.current.disk_space_permanent_bytes,
                    color: history.cpuColor
                },
                {
                    value: history.current.disk_space_temporary_bytes,
                    color: Ui.Theme.withAlpha(history.cpuColor, 0.42)
                }
            ]
        }

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "Referenced files"
            valueText: Resources.bytes(history.current.referenced_file_disk_bytes)
            detailText: Resources.bytes(history.current.referenced_file_temporary_bytes) + " temporary"
            accentColor: history.memoryColor
            maximum: Math.max(1, Number(history.current.referenced_file_disk_bytes || 0))
            uiScale: history.uiScale
            available: history.referencedFilesAvailable
            segments: [
                {
                    value: history.current.referenced_file_permanent_bytes,
                    color: history.memoryColor
                },
                {
                    value: history.current.referenced_file_temporary_bytes,
                    color: Ui.Theme.withAlpha(history.memoryColor, 0.42)
                }
            ]
        }

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "GPU allocation"
            valueText: Resources.bytes(history.current.gpu_memory_allocated_bytes)
            detailText: Resources.bytes(history.current.gpu_memory_resident_bytes) + " resident"
            accentColor: history.gpuColor
            maximum: Math.max(1, Number(history.current.gpu_memory_allocated_bytes || 0))
            uiScale: history.uiScale
            available: history.gpuAvailable
            segments: [
                {
                    value: history.current.gpu_memory_resident_bytes,
                    color: history.gpuColor
                },
                {
                    value: Math.max(0, Number(history.current.gpu_memory_allocated_bytes || 0) - Number(history.current.gpu_memory_resident_bytes || 0)),
                    color: Ui.Theme.withAlpha(history.gpuColor, 0.35)
                }
            ]
        }

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "Energy share"
            valueText: Resources.percent(history.energyFraction * 100)
            detailText: Resources.text(history.current.energy_confidence, "Estimated") + " confidence"
            accentColor: history.powerColor
            maximum: 1
            uiScale: history.uiScale
            available: history.energyAvailable
            segments: [
                {
                    value: history.energyFraction,
                    color: history.powerColor
                }
            ]
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingMd

        Ui.SectionLabel {
            Layout.fillWidth: true
            text: history.controller.historyInFlight ? "Activity overview · Loading…" : history.application.running ? "Activity overview" : "Retained activity"
        }

        Ui.SegmentedControl {
            Layout.preferredWidth: Math.round(164 * history.uiScale)
            Layout.preferredHeight: Math.round(32 * history.uiScale)
            options: [
                {
                    value: "30m",
                    label: "30m"
                },
                {
                    value: "2h",
                    label: "2h"
                },
                {
                    value: "24h",
                    label: "24h"
                }
            ]
            value: history.controller.historyRange
            onSelected: function (value) {
                history.controller.selectHistoryRange(value);
            }
        }
    }

    ApplicationResourceLaneChart {
        Layout.fillWidth: true
        title: qsTr("Shared timeline")
        points: history.points
        summaries: history.controller.resourceHistorySummary ? history.controller.resourceHistorySummary.metrics : ({})
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        maximumGapMilliseconds: Math.max(30000, (rangeEndMilliseconds - rangeStartMilliseconds) / 500)
        uiScale: history.uiScale
        lanes: [history.lane("CPU", Presentation.cpuText(history.current.cpu_percent_of_machine), "", history.reference("cpu_percent_of_machine", "cpu_percent_of_machine", "percent"), history.cpuColor, 100, !history.cpuAvailable, "area", [history.graphSeries("cpu_percent_of_machine", "cpu_percent_of_machine", "CPU", history.cpuColor, "percent", 0)]), history.lane("Memory", Presentation.memoryText(history.current.memory_bytes), "", history.reference("memory_bytes", "memory_bytes", "bytes"), history.memoryColor, 0, !history.memoryAvailable, "area", [history.graphSeries("memory_bytes", "memory_bytes", "Memory", history.memoryColor, "bytes", 0)]), history.lane("GPU", Presentation.cpuText(history.current.gpu_busy_percent), "", history.reference("gpu_busy_percent", "gpu_busy_percent", "percent"), history.gpuColor, 100, !history.gpuAvailable, "area", [history.graphSeries("gpu_busy_percent", "gpu_busy_percent", "GPU", history.gpuColor, "percent", 0)]), history.lane("Disk I/O", "Read  " + Resources.rate(history.current.disk_read_bytes_per_second), "Write  " + Resources.rate(history.current.disk_write_bytes_per_second), "", history.diskColor, 0, !history.storageAvailable, "paired", [history.graphSeries("disk_read_bytes_per_second", "disk_read_bytes_per_second", "Read", history.diskColor, "rate", 1), history.graphSeries("disk_write_bytes_per_second", "disk_write_bytes_per_second", "Write", Ui.Theme.withAlpha(history.diskColor, 0.7), "rate", -1)]), history.lane("Network", "Receive  " + Resources.rate(history.current.network_receive_bytes_per_second), "Transmit  " + Resources.rate(history.current.network_transmit_bytes_per_second), "", history.networkReceiveColor, 0, !history.networkBytesAvailable, "paired", [history.graphSeries("network_receive_bytes_per_second", "", "Receive", history.networkReceiveColor, "rate", 1), history.graphSeries("network_transmit_bytes_per_second", "", "Transmit", history.networkTransmitColor, "rate", -1)]), history.lane("Power", Resources.power(history.currentPower()), "", history.reference("average_power_watts", "estimated_app_power_watts", "power"), history.powerColor, 0, !history.energyAvailable, "area", [history.graphSeries("average_power_watts", "estimated_app_power_watts", "Application power", history.powerColor, "power", 0)])]
    }
}
