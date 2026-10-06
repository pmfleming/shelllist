pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Ui.DetailSection {
    id: overview
    objectName: "applicationResourceOverview"
    informationOnly: true

    required property var application
    required property var latestPoint
    required property var summary
    required property string rangeLabel
    required property string periodEnergyConfidence
    required property bool historyLoading
    required property real uiScale
    readonly property var current: application.running ? application : latestPoint || ({})
    readonly property string memorySource: application.running ? Resources.text((application.measurement || {}).memory_source, "unknown") : "not recorded"
    readonly property string observationStatus: application.running ? qsTr("Latest application snapshot")
        : latestPoint ? qsTr("App stopped · retained measurements from %1").arg(Qt.formatDateTime(new Date(latestPoint.timestamp_ms), "yyyy-MM-dd HH:mm:ss")) : qsTr("App is not running · no retained measurements")
    readonly property string energyConfidence: has("average_power_watts") ? qsTr("Estimated · %1 confidence").arg(Resources.text(current.energy_confidence, "unknown")) : qsTr("Energy attribution unavailable")

    function has(metric: string): bool {
        return application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(latestPoint, metric);
    }
    function value(metric: string, kind: string): string {
        return has(metric) ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : current[metric], kind) : qsTr("Unavailable");
    }
    function period(metric: string): string {
        return historyLoading ? qsTr("Loading…") : Resources.periodText(summary, metric);
    }
    function observed(metric: string): string {
        return historyLoading ? qsTr("Loading selected range…") : Resources.observationText(summary, metric);
    }

    Ui.ThemeText {
        objectName: "applicationResourceSnapshotStatus"
        Layout.fillWidth: true
        text: overview.observationStatus
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("Known disk data: %1 · RAM: %2").arg(overview.value("disk_space_total_bytes", "bytes")).arg(overview.value("memory_bytes", "bytes"))
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        title: qsTr("Space on disk")
        ApplicationResourceCapacity {
            objectName: "applicationDiskFootprint"
            Layout.fillWidth: true
            label: qsTr("Identified app data · not the complete installation")
            valueText: overview.value("disk_space_total_bytes", "bytes")
            available: overview.has("disk_space_total_bytes")
            detailText: qsTr("Persistent: %1\nTemporary: %2").arg(overview.value("disk_space_permanent_bytes", "bytes")).arg(overview.value("disk_space_temporary_bytes", "bytes"))
            accentColor: Ui.Theme.resourceDisk
            uiScale: overview.uiScale
            segments: overview.has("disk_space_permanent_bytes") && overview.has("disk_space_temporary_bytes") ? [
                {value: overview.current.disk_space_permanent_bytes, color: Ui.Theme.resourceDisk},
                {value: overview.current.disk_space_temporary_bytes, color: Ui.Theme.resourceGpu}
            ] : []
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Installation + shared dependencies: not measured. No complete disk total yet. The bar shows app-data composition, not disk capacity; temporary does not mean safe to delete.")
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        Ui.ThemeText {
            objectName: "applicationReferencedFiles"
            Layout.fillWidth: true
            text: qsTr("Referenced files: %1 · temporary: %2\nMay overlap app data or be shared; not added to the total.").arg(overview.value("referenced_file_disk_bytes", "bytes")).arg(overview.value("referenced_file_temporary_bytes", "bytes"))
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }

    Ui.ThemeText {
        Layout.fillWidth: true
        text: overview.application.running ? qsTr("Using right now") : qsTr("Last observed usage")
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= 620 * overview.uiScale ? 4 : 2
        columnSpacing: Ui.Theme.spacingSm
        rowSpacing: Ui.Theme.spacingSm
        ApplicationResourceCapacity {
            objectName: "applicationRam"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            label: qsTr("RAM")
            valueText: overview.value("memory_bytes", "bytes")
            available: overview.has("memory_bytes")
            detailText: overview.memorySource === "pss" ? qsTr("PSS · shared pages apportioned\nSwap: %1").arg(overview.value("memory_swap_bytes", "bytes"))
                : qsTr("Memory source: %1\nSwap: %2").arg(overview.memorySource.toUpperCase()).arg(overview.value("memory_swap_bytes", "bytes"))
            accentColor: Ui.Theme.resourceMemory
            uiScale: overview.uiScale
        }
        ApplicationResourceCapacity {
            objectName: "applicationGpuMemory"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            label: qsTr("GPU memory · resident")
            valueText: overview.value("gpu_memory_resident_bytes", "bytes")
            available: overview.has("gpu_memory_resident_bytes")
            detailText: qsTr("Allocated: %1\nNot added to RAM").arg(overview.value("gpu_memory_allocated_bytes", "bytes"))
            accentColor: Ui.Theme.resourceGpu
            uiScale: overview.uiScale
        }
        ApplicationResourceCapacity {
            objectName: "applicationCpuActivity"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            label: qsTr("CPU activity")
            valueText: overview.value("cpu_percent_of_machine", "percent")
            available: overview.has("cpu_percent_of_machine")
            detailText: qsTr("Of total machine capacity\nObserved processes only")
            accentColor: Ui.Theme.resourceCpu
            uiScale: overview.uiScale
        }
        ApplicationResourceCapacity {
            objectName: "applicationGpuActivity"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            label: qsTr("GPU activity")
            valueText: overview.value("gpu_busy_percent", "percent")
            available: overview.has("gpu_busy_percent")
            detailText: overview.has("gpu_busy_percent") ? qsTr("Engine busy time") : qsTr("Per-app GPU counters unavailable")
            accentColor: Ui.Theme.resourceGpu
            uiScale: overview.uiScale
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        title: qsTr("Energy")
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Ui.Theme.spacingSm
            ApplicationResourceCapacity {
                objectName: "applicationPower"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                label: overview.application.running ? qsTr("Power now") : qsTr("Last observed power")
                valueText: overview.value("average_power_watts", "power")
                available: overview.has("average_power_watts")
                detailText: overview.energyConfidence
                accentColor: Ui.Theme.resourcePower
                uiScale: overview.uiScale
            }
            ApplicationResourceCapacity {
                objectName: "applicationPeriodEnergy"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                label: qsTr("Energy · %1").arg(overview.rangeLabel)
                valueText: overview.period("average_power_watts")
                available: overview.historyLoading || Resources.periodEstimate(overview.summary, "average_power_watts") !== null
                detailText: overview.observed("average_power_watts")
                    + (Resources.periodEstimate(overview.summary, "average_power_watts") !== null ? "\n" + qsTr("Estimated · %1 confidence").arg(overview.periodEnergyConfidence) : "")
                accentColor: Ui.Theme.resourcePower
                uiScale: overview.uiScale
            }
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Estimated share of measured CPU-package energy, not total app electricity. Period energy is integrated over observed intervals only; confidence may vary by interval. No battery-life claim.")
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        title: qsTr("Data moved")
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Rates %1 · estimated totals over %2").arg(overview.application.running ? qsTr("now") : qsTr("at last observation")).arg(overview.rangeLabel)
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Ui.Theme.spacingSm
            rowSpacing: Ui.Theme.spacingSm
            Repeater {
                model: [
                    {label: qsTr("Disk read"), metric: "disk_read_bytes_per_second", tone: Ui.Theme.resourceDisk},
                    {label: qsTr("Disk write"), metric: "disk_write_bytes_per_second", tone: Ui.Theme.resourceDisk},
                    {label: qsTr("Network receive"), metric: "network_receive_bytes_per_second", tone: Ui.Theme.resourceNetworkReceive},
                    {label: qsTr("Network send"), metric: "network_transmit_bytes_per_second", tone: Ui.Theme.resourceNetworkTransmit}
                ]
                delegate: ApplicationResourceCapacity {
                    required property var modelData
                    objectName: "applicationIo_" + modelData.metric
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    label: modelData.label
                    valueText: overview.value(modelData.metric, "rate")
                    available: overview.has(modelData.metric)
                    detailText: overview.period(modelData.metric) + " · " + overview.rangeLabel + "\n" + overview.observed(modelData.metric)
                        + (overview.has(modelData.metric) ? "" : "\n" + qsTr("Per-app byte attribution unavailable; not zero traffic"))
                    accentColor: modelData.tone
                    uiScale: overview.uiScale
                }
            }
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Disk I/O is storage-layer traffic, not disk space. Memory I/O / bandwidth: not measured. RAM is occupied space; logical file I/O is not DRAM bandwidth. Totals omit missing intervals.")
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
}
