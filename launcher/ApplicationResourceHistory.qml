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
    readonly property bool gpuAvailable: application.running
        ? !!measurement.gpu_available : historyHas("gpu_busy_percent") || historyHas("gpu_percent")
    readonly property bool storageAvailable: application.running
        ? !!measurement.storage_available : historyHas("disk_read_bytes_per_second")
            || historyHas("logical_read_bytes_per_second")
    readonly property bool diskSpaceAvailable: application.running
        ? measurement.disk_space_scope !== "unavailable" : historyHas("disk_space_total_bytes")
    readonly property bool referencedFilesAvailable: storageAvailable
        || historyHas("referenced_file_disk_bytes")
    readonly property bool networkBytesAvailable: application.running
        ? !!measurement.network_bytes_available : historyHas("network_receive_bytes_per_second")
            || historyHas("network_transmit_bytes_per_second")
    readonly property bool networkConnectionsAvailable: application.running
        ? !!measurement.network_connections_available : historyHas("network_connection_count")
    readonly property bool energyAvailable: application.running
        ? application.energy_source && application.energy_source !== "unavailable" : historyHasEnergy()
    readonly property real energyFraction: Math.max(0, Math.min(1,
        Number(current.attributed_fraction || 0)))

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
    function peak(metric, nested) {
        return points.reduce(function (maximum, point) {
            const source = nested ? point.peaks || ({}) : point;
            const value = Number(source[metric] || 0);
            return isFinite(value) ? Math.max(maximum, value) : maximum;
        }, 0);
    }
    function graphSeries(metric, peakMetric, label, color, kind, dashed) {
        return { metric: metric, peakMetric: peakMetric || "", label: label,
            color: color, kind: kind, dashed: !!dashed };
    }
    function lane(label, valueText, color, maximum, unavailable, series) {
        return { label: label, valueText: valueText, color: color, maximum: maximum,
            unavailable: unavailable, series: series };
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingMd
        Ui.SectionLabel {
            Layout.fillWidth: true
            text: history.controller.historyInFlight
                ? "Resource history · Loading…"
                : history.application.running ? "Live resource history" : "Retained resource history"
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

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        ApplicationResourceBullet {
            Layout.fillWidth: true
            label: "CPU"
            valueText: Presentation.cpuText(history.current.cpu_percent_of_machine)
            value: Number(history.current.cpu_percent_of_machine || 0)
            peak: history.peak("cpu_percent_of_machine", true)
            maximum: 100
            accentColor: Ui.Theme.accent
            uiScale: history.uiScale
        }
        ApplicationResourceBullet {
            Layout.fillWidth: true
            label: "Memory"
            valueText: Presentation.memoryText(history.current.memory_bytes)
            value: Number(history.current.memory_bytes || 0)
            peak: history.peak("memory_bytes", true)
            maximum: Math.max(value, peak, 1) * 1.08
            accentColor: Ui.Theme.active
            uiScale: history.uiScale
        }
        ApplicationResourceBullet {
            Layout.fillWidth: true
            label: "GPU"
            valueText: Presentation.cpuText(history.current.gpu_busy_percent)
            value: Number(history.current.gpu_busy_percent || 0)
            peak: history.peak("gpu_busy_percent", true)
            maximum: 100
            available: history.gpuAvailable
            accentColor: Ui.Theme.warning
            uiScale: history.uiScale
        }
        ApplicationResourceBullet {
            Layout.fillWidth: true
            label: "Estimated power"
            valueText: Resources.power(history.currentPower())
            value: history.currentPower()
            peak: history.peak("estimated_app_power_watts", true)
            maximum: Math.max(value, peak, 1) * 1.08
            available: history.energyAvailable
            accentColor: Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.accent, 0.45)
            uiScale: history.uiScale
        }
    }

    ApplicationResourceLaneChart {
        Layout.fillWidth: true
        title: "Resource pressure over time"
        points: history.points
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        uiScale: history.uiScale
        lanes: [
            history.lane("CPU", Resources.percent(history.current.cpu_percent_of_machine),
                Ui.Theme.accent, 100, false, [
                    history.graphSeries("cpu_percent_of_machine", "", "CPU", Ui.Theme.accent, "percent", false)
                ]),
            history.lane("GPU", Resources.percent(history.current.gpu_busy_percent),
                Ui.Theme.warning, 100, !history.gpuAvailable, [
                    history.graphSeries("gpu_busy_percent", "", "Busiest", Ui.Theme.warning, "percent", false),
                    history.graphSeries("gpu_percent", "", "Aggregate", Ui.Theme.mix(Ui.Theme.warning, Ui.Theme.accent, 0.45), "percent", false)
                ]),
            history.lane("Memory", Resources.bytes(history.current.memory_bytes),
                Ui.Theme.active, 0, false, [
                    history.graphSeries("memory_bytes", "", "Best", Ui.Theme.active, "bytes", false),
                    history.graphSeries("memory_private_bytes", "", "Private", Ui.Theme.accent, "bytes", false),
                    history.graphSeries("memory_swap_bytes", "", "Swap", Ui.Theme.warning, "bytes", false)
                ]),
            history.lane("GPU mem", Resources.bytes(history.current.gpu_memory_bytes),
                Ui.Theme.warning, 0, !history.gpuAvailable, [
                    history.graphSeries("gpu_memory_resident_bytes", "", "Resident", Ui.Theme.warning, "bytes", false),
                    history.graphSeries("gpu_memory_allocated_bytes", "", "Allocated", Ui.Theme.accent, "bytes", false)
                ])
        ]
    }

    ApplicationResourceLaneChart {
        Layout.fillWidth: true
        title: "Storage activity"
        points: history.points
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        uiScale: history.uiScale
        lanes: [
            history.lane("Physical R/W", "R " + Resources.rate(history.current.disk_read_bytes_per_second),
                Ui.Theme.accent, 0, !history.storageAvailable, [
                    history.graphSeries("disk_read_bytes_per_second", "", "Read", Ui.Theme.accent, "rate", false),
                    history.graphSeries("disk_write_bytes_per_second", "", "Write", Ui.Theme.warning, "rate", false)
                ]),
            history.lane("Logical R/W", "R " + Resources.rate(history.current.logical_read_bytes_per_second),
                Ui.Theme.active, 0, !history.storageAvailable, [
                    history.graphSeries("logical_read_bytes_per_second", "", "Read", Ui.Theme.active, "rate", false),
                    history.graphSeries("logical_write_bytes_per_second", "", "Write", Ui.Theme.warning, "rate", false)
                ]),
            history.lane("Ops R/W", Resources.operationsRate(history.current.read_operations_per_second),
                Ui.Theme.warning, 0, !history.storageAvailable, [
                    history.graphSeries("read_operations_per_second", "", "Read", Ui.Theme.accent, "ops", false),
                    history.graphSeries("write_operations_per_second", "", "Write", Ui.Theme.warning, "ops", false)
                ])
        ]
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Math.round(Ui.Theme.spacingSm * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingSm * history.uiScale)

        ApplicationResourceDonut {
            Layout.fillWidth: true
            label: "Application data"
            uiScale: history.uiScale
            available: history.diskSpaceAvailable
            segments: [
                { value: history.current.disk_space_permanent_bytes, color: Ui.Theme.accent },
                { value: history.current.disk_space_temporary_bytes, color: Ui.Theme.warning }
            ]
        }
        ApplicationResourceDonut {
            Layout.fillWidth: true
            label: "Referenced files"
            uiScale: history.uiScale
            available: history.referencedFilesAvailable
            segments: [
                { value: history.current.referenced_file_permanent_bytes, color: Ui.Theme.active },
                { value: history.current.referenced_file_temporary_bytes, color: Ui.Theme.warning }
            ]
        }
        ApplicationResourceDonut {
            Layout.fillWidth: true
            label: "GPU allocation"
            uiScale: history.uiScale
            available: history.gpuAvailable
            segments: [
                { value: history.current.gpu_memory_resident_bytes, color: Ui.Theme.warning },
                { value: Math.max(0, Number(history.current.gpu_memory_allocated_bytes || 0)
                    - Number(history.current.gpu_memory_resident_bytes || 0)), color: Ui.Theme.accent }
            ]
        }
        ApplicationResourceDonut {
            Layout.fillWidth: true
            label: "Energy share"
            uiScale: history.uiScale
            available: history.energyAvailable
            centerText: Resources.percent(history.energyFraction * 100)
            segments: [
                { value: history.energyFraction, color: Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.accent, 0.45) },
                { value: 1 - history.energyFraction, color: Ui.Theme.input }
            ]
        }
    }

    ApplicationResourceLaneChart {
        Layout.fillWidth: true
        title: "Runtime activity"
        points: history.points
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        uiScale: history.uiScale
        lanes: [
            history.lane("Proc/threads", Resources.integer(history.current.process_count),
                Ui.Theme.accent, 0, false, [
                    history.graphSeries("process_count", "", "Processes", Ui.Theme.accent, "count", false),
                    history.graphSeries("thread_count", "", "Threads", Ui.Theme.active, "count", false)
                ]),
            history.lane("Faults", Resources.decimal(history.current.major_faults_per_second, 2) + "/s",
                Ui.Theme.warning, 0, false, [
                    history.graphSeries("major_faults_per_second", "", "Faults", Ui.Theme.warning, "faults", false)
                ]),
            history.lane("Connections", Resources.integer(history.current.network_connection_count),
                Ui.Theme.accent, 0, !history.networkConnectionsAvailable, [
                    history.graphSeries("network_connection_count", "", "Connections", Ui.Theme.accent, "count", false)
                ]),
            history.lane("Traffic Rx/Tx", "Rx " + Resources.rate(history.current.network_receive_bytes_per_second),
                Ui.Theme.active, 0, !history.networkBytesAvailable, [
                    history.graphSeries("network_receive_bytes_per_second", "", "Receive", Ui.Theme.active, "rate", false),
                    history.graphSeries("network_transmit_bytes_per_second", "", "Transmit", Ui.Theme.warning, "rate", false)
                ])
        ]
    }

    ApplicationResourceMultiGraph {
        Layout.fillWidth: true
        points: history.points
        uiScale: history.uiScale
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        available: history.energyAvailable
        chartStyle: "area"
        label: "Application power and system context"
        valueText: history.energyAvailable ? Resources.power(history.currentPower()) : ""
        series: [
            history.graphSeries("average_power_watts", "estimated_app_power_watts", "Application",
                Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.accent, 0.45), "power", false),
            history.graphSeries("system_power_watts", "", "System", Ui.Theme.mutedText, "power", true)
        ]
    }
}
