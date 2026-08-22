pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

ColumnLayout {
    id: history

    required property ApplicationController controller
    required property var application
    required property real uiScale

    readonly property var measurement: application.measurement || ({})
    readonly property bool hasHistory: (controller.resourceHistory || []).length > 0

    function historyHas(metric) {
        return (controller.resourceHistory || []).some(function (point) {
            const value = Number(point[metric] || 0);
            return isFinite(value) && value > 0;
        });
    }
    function historyHasEnergy() {
        return (controller.resourceHistory || []).some(function (point) {
            return point.energy_source && point.energy_source !== "unavailable";
        });
    }
    function graphModels() {
        const running = !!application.running;
        const models = [{
            metric: "cpu_percent_of_machine", label: "CPU",
            value: Presentation.cpuText(application.cpu_percent_of_machine),
            color: Ui.Theme.accent, minimum: 10, available: true
        }, {
            metric: "memory_bytes", label: "Memory",
            value: Presentation.memoryText(application.memory_bytes),
            color: Ui.Theme.active, minimum: 0, available: true
        }, {
            metric: "gpu_busy_percent", label: "GPU",
            value: Presentation.cpuText(application.gpu_busy_percent || application.gpu_percent),
            color: Ui.Theme.warning, minimum: 10,
            available: running ? !!measurement.gpu_available : historyHas("gpu_busy_percent") || historyHas("gpu_percent")
        }, {
            metric: "disk_read_bytes_per_second", label: "Disk read",
            value: Presentation.rateText(application.disk_read_bytes_per_second),
            color: Ui.Theme.accent, minimum: 0,
            available: running ? !!measurement.storage_available : historyHas("disk_read_bytes_per_second")
        }, {
            metric: "disk_write_bytes_per_second", label: "Disk write",
            value: Presentation.rateText(application.disk_write_bytes_per_second),
            color: Ui.Theme.warning, minimum: 0,
            available: running ? !!measurement.storage_available : historyHas("disk_write_bytes_per_second")
        }, {
            metric: "disk_space_permanent_bytes", label: "Permanent storage",
            value: Presentation.memoryText(application.disk_space_permanent_bytes),
            color: Ui.Theme.accent, minimum: 0,
            available: running ? measurement.disk_space_scope !== "unavailable" : historyHas("disk_space_permanent_bytes")
        }, {
            metric: "disk_space_temporary_bytes", label: "Cache & temporary",
            value: Presentation.memoryText(application.disk_space_temporary_bytes),
            color: Ui.Theme.warning, minimum: 0,
            available: running ? measurement.disk_space_scope !== "unavailable" : historyHas("disk_space_temporary_bytes")
        }, {
            metric: "average_power_watts", label: "Estimated power",
            value: Presentation.powerText(application.estimated_app_power_watts || application.power_watts),
            color: Ui.Theme.active, minimum: 0,
            available: running ? application.energy_source !== "unavailable" : historyHasEnergy()
        }];
        return models.filter(function (model) { return model.available; });
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        text: history.controller.historyInFlight
            ? "Resource history · Loading…"
            : history.application.running
                ? "Resource history · Last 30 minutes"
                : "Retained resource history · Last 30 minutes"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        Repeater {
            model: history.graphModels()

            delegate: ApplicationResourceGraph {
                required property var modelData
                points: history.controller.resourceHistory
                uiScale: history.uiScale
                metric: modelData.metric
                label: modelData.label
                valueText: modelData.value
                lineColor: modelData.color
                minimumMaximum: modelData.minimum
            }
        }
    }
}
