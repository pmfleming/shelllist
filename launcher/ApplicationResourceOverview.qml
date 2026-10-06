pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// Read-only disclosure. The compact rows own the latest values; this section
// retains statistics, attribution and safety qualifications without duplicating
// the overview card stack or introducing new field stops.
Ui.DetailSection {
    id: details
    informationOnly: true
    readonly property Item revealTarget: heading

    required property var application
    required property var latestPoint
    required property var lanes
    required property var footprint
    required property string memorySource
    required property string swapText
    required property string allocatedText
    required property string referencedText
    required property real uiScale
    readonly property var metrics: lanes.reduce((result, lane) => result.concat(lane.series), [])

    Ui.ThemeText {
        id: heading
        Layout.fillWidth: true
        text: qsTr("Measurement details")
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightMedium
        wrapMode: Text.Wrap
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Ui.Theme.spacingSm
        rowSpacing: Ui.Theme.spacingSm
        Repeater {
            model: [qsTr("Metric"), qsTr("Average / peak"), qsTr("Observed time")]
            delegate: Ui.ThemeText {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                text: modelData
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }
        Repeater {
            model: details.metrics.reduce((result, metric) => result.concat([metric.label, Resources.formatted(metric.mean, metric.kind) + " / " + Resources.formatted(metric.peak, metric.kind), metric.observation]), [])
            delegate: Ui.ThemeText {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                text: modelData
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeCaption
                color: Ui.Theme.mutedText
            }
        }
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: details.footprint.detailText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: Ui.Theme.mutedText
    }
    Ui.ThemeText {
        objectName: "applicationReferencedFiles"
        Layout.fillWidth: true
        text: details.referencedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: Ui.Theme.mutedText
    }
    Ui.ThemeText {
        objectName: "applicationMemoryDetails"
        Layout.fillWidth: true
        text: qsTr("RAM source: %1 · Swap: %2. GPU allocated: %3. GPU memory is not added to RAM. Retained samples do not record PSS/RSS source.").arg(details.memorySource).arg(details.swapText).arg(details.allocatedText)
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: Ui.Theme.mutedText
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("CPU is a percentage of total machine capacity; GPU is engine busy time. Each group has its own labeled scale. Solid/dashed memory traces are RAM/GPU resident, never stacked. Steps and columns describe retained bucket intervals, not exact event times. Read/receive are above centre; write/send below. Hatched regions are missing measurements; paired directions have separate halves, overlaid traces separate coverage bands (first series above second). ◷ denotes observed/selected time, not process coverage.")
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: Ui.Theme.mutedText
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("Disk I/O is storage-layer traffic, not disk space. Memory bandwidth is not measured. Averages and ≈ period totals use valid observed intervals only; missing time is not zero. Power and energy estimate a share of measured CPU-package energy, not whole-system electricity or battery drain. Period confidence is the weakest known confidence in valid retained energy samples, or unknown. No battery-life claim. Sampling interval is not snapshot age.")
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: Ui.Theme.mutedText
    }
    ApplicationResourceMetadata {
        Layout.fillWidth: true
        application: details.application
        latestPoint: details.latestPoint
        uiScale: details.uiScale
    }
}
