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

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        text: history.controller.historyInFlight
            ? "Resource history · Loading…"
            : "Resource history · Last 30 minutes"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingMd * history.uiScale)

        Repeater {
            model: [{
                metric: "cpu_percent_of_machine", label: "CPU",
                value: Presentation.cpuText(history.application.cpu_percent_of_machine),
                color: Ui.Theme.accent, minimum: 10
            }, {
                metric: "memory_bytes", label: "Memory",
                value: Presentation.memoryText(history.application.memory_bytes),
                color: Ui.Theme.active, minimum: 0
            }, {
                metric: "gpu_busy_percent", label: "GPU",
                value: Presentation.cpuText(history.application.gpu_busy_percent || history.application.gpu_percent),
                color: Ui.Theme.warning, minimum: 10
            }, {
                metric: "disk_read_bytes_per_second", label: "Disk read",
                value: Presentation.rateText(history.application.disk_read_bytes_per_second),
                color: Ui.Theme.accent, minimum: 0
            }, {
                metric: "disk_write_bytes_per_second", label: "Disk write",
                value: Presentation.rateText(history.application.disk_write_bytes_per_second),
                color: Ui.Theme.warning, minimum: 0
            }, {
                metric: "disk_space_permanent_bytes", label: "Permanent storage",
                value: Presentation.memoryText(history.application.disk_space_permanent_bytes),
                color: Ui.Theme.accent, minimum: 0
            }, {
                metric: "disk_space_temporary_bytes", label: "Cache & temporary",
                value: Presentation.memoryText(history.application.disk_space_temporary_bytes),
                color: Ui.Theme.warning, minimum: 0
            }, {
                metric: "average_power_watts", label: "Estimated power",
                value: Presentation.powerText(history.application.estimated_app_power_watts || history.application.power_watts),
                color: Ui.Theme.active, minimum: 0
            }]

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
