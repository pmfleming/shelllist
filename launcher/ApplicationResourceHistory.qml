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
    readonly property bool hasHistory: points.length > 0
    readonly property bool gpuAvailable: application.running
        ? !!measurement.gpu_available : historyHas("gpu_busy_percent") || historyHas("gpu_percent")
    readonly property bool storageAvailable: application.running
        ? !!measurement.storage_available : historyHas("disk_read_bytes_per_second")
            || historyHas("logical_read_bytes_per_second")
    readonly property bool diskSpaceAvailable: application.running
        ? measurement.disk_space_scope !== "unavailable" : historyHas("disk_space_total_bytes")
    readonly property bool networkBytesAvailable: application.running
        ? !!measurement.network_bytes_available : historyHas("network_receive_bytes_per_second")
            || historyHas("network_transmit_bytes_per_second")
    readonly property bool networkConnectionsAvailable: application.running
        ? !!measurement.network_connections_available : historyHas("network_connection_count")
    readonly property bool energyAvailable: application.running
        ? application.energy_source && application.energy_source !== "unavailable" : historyHasEnergy()

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
    function graphSeries(metric, peakMetric, label, color, kind, dashed) {
        return { metric: metric, peakMetric: peakMetric || "", label: label,
            color: color, kind: kind, dashed: !!dashed };
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

        ApplicationResourceGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            metric: "cpu_percent_of_machine"
            peakMetric: "cpu_percent_of_machine"
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "CPU"
            valueText: Presentation.cpuText(history.current.cpu_percent_of_machine)
            lineColor: Ui.Theme.accent
            minimumMaximum: 10
        }
        ApplicationResourceGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            metric: "memory_bytes"
            peakMetric: "memory_bytes"
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Memory"
            valueText: Presentation.memoryText(history.current.memory_bytes)
            lineColor: Ui.Theme.active
        }
        ApplicationResourceGraph {
            visible: history.gpuAvailable
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            metric: "gpu_busy_percent"
            peakMetric: "gpu_busy_percent"
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "GPU"
            valueText: Presentation.cpuText(history.current.gpu_busy_percent)
            lineColor: Ui.Theme.warning
            minimumMaximum: 10
        }
        ApplicationResourceGraph {
            visible: history.energyAvailable
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            metric: "average_power_watts"
            peakMetric: "estimated_app_power_watts"
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Estimated power"
            valueText: Resources.power(history.currentPower())
            lineColor: Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.accent, 0.45)
        }
    }

    Ui.SectionLabel { text: "Compute activity" }

    ApplicationResourceMultiGraph {
        Layout.fillWidth: true
        points: history.points
        uiScale: history.uiScale
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        minimumMaximum: 100
        label: history.gpuAvailable ? "CPU and GPU occupancy" : "CPU occupancy"
        valueText: Resources.percent(history.current.cpu_percent_of_machine)
        series: [
            history.graphSeries("cpu_percent_of_machine", "cpu_percent_of_machine",
                "CPU", Ui.Theme.accent, "percent", false)
        ].concat(history.gpuAvailable ? [
            history.graphSeries("gpu_busy_percent", "gpu_busy_percent",
                "GPU busiest", Ui.Theme.warning, "percent", false),
            history.graphSeries("gpu_percent", "gpu_percent",
                "GPU aggregate", Ui.Theme.mix(Ui.Theme.warning, Ui.Theme.accent, 0.45), "percent", true)
        ] : [])
    }

    ApplicationResourceMultiGraph {
        Layout.fillWidth: true
        points: history.points
        uiScale: history.uiScale
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        label: "Memory breakdown"
        valueText: Resources.bytes(history.current.memory_bytes)
        series: [
            history.graphSeries("memory_bytes", "memory_bytes", "Best estimate", Ui.Theme.active, "bytes", false),
            history.graphSeries("memory_private_bytes", "", "Private", Ui.Theme.accent, "bytes", false),
            history.graphSeries("memory_swap_bytes", "", "Swap", Ui.Theme.warning, "bytes", true),
            history.graphSeries("memory_cgroup_bytes", "", "Cgroup", Ui.Theme.mutedText, "bytes", true)
        ]
    }

    ApplicationResourceMultiGraph {
        visible: history.gpuAvailable
        Layout.fillWidth: true
        points: history.points
        uiScale: history.uiScale
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        label: "GPU memory"
        valueText: Resources.bytes(history.current.gpu_memory_bytes)
        series: [
            history.graphSeries("gpu_memory_resident_bytes", "", "Resident", Ui.Theme.warning, "bytes", false),
            history.graphSeries("gpu_memory_allocated_bytes", "", "Allocated", Ui.Theme.accent, "bytes", true)
        ]
    }

    Ui.SectionLabel { visible: history.storageAvailable || history.diskSpaceAvailable; text: "Storage and I/O" }

    GridLayout {
        visible: history.storageAvailable
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        ApplicationResourceMultiGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Physical I/O"
            valueText: "R " + Resources.rate(history.current.disk_read_bytes_per_second)
            series: [
                history.graphSeries("disk_read_bytes_per_second", "disk_read_bytes_per_second", "Read", Ui.Theme.accent, "rate", false),
                history.graphSeries("disk_write_bytes_per_second", "disk_write_bytes_per_second", "Write", Ui.Theme.warning, "rate", false)
            ]
        }
        ApplicationResourceMultiGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Logical I/O"
            valueText: "R " + Resources.rate(history.current.logical_read_bytes_per_second)
            series: [
                history.graphSeries("logical_read_bytes_per_second", "", "Read", Ui.Theme.active, "rate", false),
                history.graphSeries("logical_write_bytes_per_second", "", "Write", Ui.Theme.warning, "rate", false)
            ]
        }
        ApplicationResourceMultiGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "I/O operations"
            valueText: Resources.operationsRate(history.current.read_operations_per_second)
            series: [
                history.graphSeries("read_operations_per_second", "", "Read", Ui.Theme.accent, "ops", false),
                history.graphSeries("write_operations_per_second", "", "Write", Ui.Theme.warning, "ops", false)
            ]
        }
    }

    GridLayout {
        visible: history.diskSpaceAvailable
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        ApplicationResourceComposition {
            Layout.fillWidth: true
            title: "Application data"
            uiScale: history.uiScale
            segments: [
                { label: "Permanent", value: history.current.disk_space_permanent_bytes, color: Ui.Theme.accent },
                { label: "Temporary", value: history.current.disk_space_temporary_bytes, color: Ui.Theme.warning }
            ]
        }
        ApplicationResourceComposition {
            Layout.fillWidth: true
            title: "Referenced files"
            uiScale: history.uiScale
            segments: [
                { label: "Permanent", value: history.current.referenced_file_permanent_bytes, color: Ui.Theme.active },
                { label: "Temporary", value: history.current.referenced_file_temporary_bytes, color: Ui.Theme.warning }
            ]
        }
    }

    Ui.SectionLabel { text: "Processes and network" }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        ApplicationResourceMultiGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Processes and threads"
            valueText: Resources.integer(history.current.process_count) + " processes"
            series: [
                history.graphSeries("process_count", "", "Processes", Ui.Theme.accent, "count", false),
                history.graphSeries("thread_count", "", "Threads", Ui.Theme.active, "count", false)
            ]
        }
        ApplicationResourceMultiGraph {
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Major memory faults"
            valueText: Resources.decimal(history.current.major_faults_per_second, 2) + "/s"
            series: [history.graphSeries("major_faults_per_second", "", "Faults", Ui.Theme.warning, "faults", false)]
        }
        ApplicationResourceMultiGraph {
            visible: history.networkConnectionsAvailable
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Network connections"
            valueText: Resources.integer(history.current.network_connection_count)
            series: [history.graphSeries("network_connection_count", "", "Connections", Ui.Theme.accent, "count", false)]
        }
        ApplicationResourceMultiGraph {
            visible: history.networkBytesAvailable
            Layout.fillWidth: true
            points: history.points
            uiScale: history.uiScale
            rangeStartMilliseconds: history.controller.historyWindowStartMs
            rangeEndMilliseconds: history.controller.historyWindowEndMs
            label: "Network traffic"
            valueText: "Rx " + Resources.rate(history.current.network_receive_bytes_per_second)
            series: [
                history.graphSeries("network_receive_bytes_per_second", "", "Receive", Ui.Theme.active, "rate", false),
                history.graphSeries("network_transmit_bytes_per_second", "", "Transmit", Ui.Theme.warning, "rate", false)
            ]
        }
    }

    Text {
        visible: !history.networkBytesAvailable
        Layout.fillWidth: true
        text: "Per-application network traffic accounting is unavailable"
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.SectionLabel { visible: history.energyAvailable; text: "Power and energy" }

    ApplicationResourceMultiGraph {
        visible: history.energyAvailable
        Layout.fillWidth: true
        points: history.points
        uiScale: history.uiScale
        rangeStartMilliseconds: history.controller.historyWindowStartMs
        rangeEndMilliseconds: history.controller.historyWindowEndMs
        label: "Application estimate and system context"
        valueText: Resources.power(history.currentPower())
        series: [
            history.graphSeries("average_power_watts", "estimated_app_power_watts", "Application estimate",
                Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.accent, 0.45), "power", false),
            history.graphSeries("system_power_watts", "", "System context", Ui.Theme.mutedText, "power", true)
        ]
    }
}
