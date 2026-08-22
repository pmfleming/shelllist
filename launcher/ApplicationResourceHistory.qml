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

    readonly property var measurement: application.measurement || ({})
    readonly property var points: controller.resourceHistory || []
    readonly property var latestPoint: points.length > 0 ? points[points.length - 1] : ({})
    readonly property var current: application.running ? application : latestPoint
    readonly property bool hasMeasurements: application.running || points.length > 0
    readonly property bool gpuAvailable: application.running
        ? !!measurement.gpu_available : historyHas("gpu_busy_percent") || historyHas("gpu_percent")
    readonly property bool storageAvailable: application.running
        ? !!measurement.storage_available : historyHas("disk_read_bytes_per_second")
            || historyHas("disk_write_bytes_per_second")
    readonly property bool diskSpaceAvailable: application.running
        ? measurement.disk_space_scope !== "unavailable" : historyHas("disk_space_total_bytes")
    readonly property bool referencedFilesAvailable: storageAvailable
        || historyHas("referenced_file_disk_bytes")
    readonly property bool networkBytesAvailable: application.running
        ? !!measurement.network_bytes_available : historyHas("network_receive_bytes_per_second")
            || historyHas("network_transmit_bytes_per_second")
    readonly property bool energyAvailable: application.running
        ? application.energy_source && application.energy_source !== "unavailable" : historyHasEnergy()
    readonly property real energyFraction: Math.max(0, Math.min(1,
        Number(current.attributed_fraction || 0)))

    // Data colours are intentionally independent from the interactive UI accent.
    readonly property color cpuColor: Ui.Theme.dark ? "#60a5fa" : "#2563eb"
    readonly property color memoryColor: Ui.Theme.dark ? "#4ade80" : "#15803d"
    readonly property color gpuColor: Ui.Theme.dark ? "#fbbf24" : "#b45309"
    readonly property color diskColor: Ui.Theme.dark ? "#38bdf8" : "#0369a1"
    readonly property color networkReceiveColor: Ui.Theme.dark ? "#c084fc" : "#7e22ce"
    readonly property color networkTransmitColor: Ui.Theme.dark ? "#22d3ee" : "#0e7490"
    readonly property color powerColor: Ui.Theme.dark ? "#fb7185" : "#be123c"

    function historyHas(metric) {
        return points.some(function (point) {
            const value = Number(point[metric] || 0);
            return isFinite(value) && value > 0;
        });
    }
    function historyHasEnergy() {
        return points.some(function (point) {
            return point.energy_source && point.energy_source !== "unavailable";
        });
    }
    function currentPower() {
        return application.running
            ? application.estimated_app_power_watts || application.power_watts
            : latestPoint.average_power_watts;
    }
    function average(metric) {
        const values = points.map(function (point) { return Number(point[metric]); })
            .filter(function (value) { return isFinite(value) && value >= 0; });
        return values.length > 0 ? values.reduce(function (sum, value) {
            return sum + value;
        }, 0) / values.length : 0;
    }
    function peak(metric, nested) {
        return points.reduce(function (maximum, point) {
            const source = nested ? point.peaks || ({}) : point;
            const value = Number(source[metric] || 0);
            return isFinite(value) ? Math.max(maximum, value) : maximum;
        }, 0);
    }
    function formatted(value, kind) {
        if (kind === "bytes") return Resources.bytes(value);
        if (kind === "rate") return Resources.rate(value);
        if (kind === "power") return Resources.power(value);
        return Resources.percent(value);
    }
    function reference(metric, peakMetric, kind) {
        return "avg " + formatted(average(metric), kind) + " · peak "
            + formatted(peak(peakMetric || metric, !!peakMetric), kind);
    }
    function graphSeries(metric, peakMetric, label, color, kind, direction) {
        return { metric: metric, peakMetric: peakMetric || "", label: label,
            color: color, kind: kind, direction: direction || 0 };
    }
    function lane(label, valueText, secondaryText, referenceText, color, maximum,
            unavailable, chartStyle, series) {
        return { label: label, valueText: valueText, secondaryText: secondaryText,
            referenceText: referenceText, color: color, maximum: maximum,
            unavailable: unavailable, chartStyle: chartStyle, series: series };
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        Layout.fillWidth: true
        text: "Resource composition"
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
            detailText: Resources.bytes(history.current.disk_space_permanent_bytes)
                + " permanent"
            accentColor: history.cpuColor
            maximum: Math.max(1, Number(history.current.disk_space_total_bytes || 0))
            uiScale: history.uiScale
            available: history.diskSpaceAvailable
            segments: [
                { value: history.current.disk_space_permanent_bytes, color: history.cpuColor },
                { value: history.current.disk_space_temporary_bytes,
                    color: Ui.Theme.withAlpha(history.cpuColor, 0.42) }
            ]
        }

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "Referenced files"
            valueText: Resources.bytes(history.current.referenced_file_disk_bytes)
            detailText: Resources.bytes(history.current.referenced_file_temporary_bytes)
                + " temporary"
            accentColor: history.memoryColor
            maximum: Math.max(1, Number(history.current.referenced_file_disk_bytes || 0))
            uiScale: history.uiScale
            available: history.referencedFilesAvailable
            segments: [
                { value: history.current.referenced_file_permanent_bytes, color: history.memoryColor },
                { value: history.current.referenced_file_temporary_bytes,
                    color: Ui.Theme.withAlpha(history.memoryColor, 0.42) }
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
                { value: history.current.gpu_memory_resident_bytes, color: history.gpuColor },
                { value: Math.max(0, Number(history.current.gpu_memory_allocated_bytes || 0)
                    - Number(history.current.gpu_memory_resident_bytes || 0)),
                    color: Ui.Theme.withAlpha(history.gpuColor, 0.35) }
            ]
        }

        ApplicationResourceCapacity {
            Layout.fillWidth: true
            label: "Energy share"
            valueText: Resources.percent(history.energyFraction * 100)
            detailText: Resources.text(history.current.energy_confidence, "Estimated")
                + " confidence"
            accentColor: history.powerColor
            maximum: 1
            uiScale: history.uiScale
            available: history.energyAvailable
            segments: [
                { value: history.energyFraction, color: history.powerColor }
            ]
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingMd

        Ui.SectionLabel {
            Layout.fillWidth: true
            text: history.controller.historyInFlight
                ? "Activity overview · Loading…"
                : history.application.running ? "Activity overview" : "Retained activity"
        }

        Ui.SegmentedControl {
            Layout.preferredWidth: Math.round(164 * history.uiScale)
            Layout.preferredHeight: Math.round(32 * history.uiScale)
            options: [
                { value: "30m", label: "30m" },
                { value: "2h", label: "2h" },
                { value: "24h", label: "24h" }
            ]
            value: history.controller.historyRange
            onSelected: function (value) { history.controller.selectHistoryRange(value); }
        }
    }

    ApplicationResourceLaneChart {
        Layout.fillWidth: true
        title: "Shared timeline"
        points: history.points
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        maximumGapMilliseconds: Math.max(30000,
            (rangeEndMilliseconds - rangeStartMilliseconds) / 500)
        uiScale: history.uiScale
        lanes: [
            history.lane("CPU", Presentation.cpuText(history.current.cpu_percent_of_machine), "",
                history.reference("cpu_percent_of_machine", "cpu_percent_of_machine", "percent"),
                history.cpuColor, 100, !history.hasMeasurements, "area", [
                    history.graphSeries("cpu_percent_of_machine", "cpu_percent_of_machine",
                        "CPU", history.cpuColor, "percent", 0)
                ]),
            history.lane("Memory", Presentation.memoryText(history.current.memory_bytes), "",
                history.reference("memory_bytes", "memory_bytes", "bytes"),
                history.memoryColor, 0, !history.hasMeasurements, "area", [
                    history.graphSeries("memory_bytes", "memory_bytes",
                        "Memory", history.memoryColor, "bytes", 0)
                ]),
            history.lane("GPU", Presentation.cpuText(history.current.gpu_busy_percent), "",
                history.reference("gpu_busy_percent", "gpu_busy_percent", "percent"),
                history.gpuColor, 100, !history.gpuAvailable, "area", [
                    history.graphSeries("gpu_busy_percent", "gpu_busy_percent",
                        "GPU", history.gpuColor, "percent", 0)
                ]),
            history.lane("Disk I/O", "Read  " + Resources.rate(history.current.disk_read_bytes_per_second),
                "Write  " + Resources.rate(history.current.disk_write_bytes_per_second), "",
                history.diskColor, 0, !history.storageAvailable, "paired", [
                    history.graphSeries("disk_read_bytes_per_second", "disk_read_bytes_per_second",
                        "Read", history.diskColor, "rate", 1),
                    history.graphSeries("disk_write_bytes_per_second", "disk_write_bytes_per_second",
                        "Write", Ui.Theme.withAlpha(history.diskColor, 0.7), "rate", -1)
                ]),
            history.lane("Network", "Receive  "
                    + Resources.rate(history.current.network_receive_bytes_per_second),
                "Transmit  " + Resources.rate(history.current.network_transmit_bytes_per_second), "",
                history.networkReceiveColor, 0, !history.networkBytesAvailable, "paired", [
                    history.graphSeries("network_receive_bytes_per_second", "",
                        "Receive", history.networkReceiveColor, "rate", 1),
                    history.graphSeries("network_transmit_bytes_per_second", "",
                        "Transmit", history.networkTransmitColor, "rate", -1)
                ]),
            history.lane("Power", Resources.power(history.currentPower()), "",
                history.reference("average_power_watts", "estimated_app_power_watts", "power"),
                history.powerColor, 0, !history.energyAvailable, "area", [
                    history.graphSeries("average_power_watts", "estimated_app_power_watts",
                        "Application power", history.powerColor, "power", 0)
                ])
        ]
    }
}
