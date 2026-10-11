pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// One passive list surface. Only the range selector outside this boundary is
// editable; measurements determine the compact columns, never a pane percentage.
Ui.DetailSection {
    id: overview
    informationOnly: true
    required property var lanes
    required property var points
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    required property real uiScale
    property bool loading: false
    property bool active: true
    readonly property real contentPadding: Math.round(Ui.Theme.cardPadding * uiScale)
    readonly property real rowGap: Math.round(Ui.Theme.spacingMd * uiScale)
    readonly property real valueSize: Math.max(Ui.Theme.resourceValueMinimumSize, Math.round(Ui.Theme.formValueSize * uiScale))
    readonly property real headingSize: Math.max(Ui.Theme.fontSizeLabel, Math.round(Ui.Theme.fontSizeLabel * uiScale))
    readonly property var allReadings: rows.reduce((values, row) => values.concat(row.readings), [])
    readonly property real labelWidth: Math.ceil(Math.max(...allReadings.map(reading => labelMetrics.advanceWidth(reading.shortLabel))) + Ui.Theme.spacingSm + Ui.Theme.spacingXs)
    readonly property real valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth("999.99 mWh"), ...allReadings.map(reading => valueMetrics.advanceWidth(reading.available ? reading.valueText : "—"))))
    readonly property real readingWidth: labelWidth + Ui.Theme.spacingSm + valueWidth
    readonly property real plotLeftInset: contentPadding + readingWidth + rowGap
    readonly property real minimumRowHeight: Math.ceil(headingMetrics.height + 2 * valueMetrics.height + 4 * Ui.Theme.spacingXs)
    readonly property real minimumContentHeight: 2 * contentPadding + rows.length * minimumRowHeight
    readonly property var rows: [
        {lane: lanes[0], readings: lanes[0].series, glyph: "memory", title: qsTr("Activity")},
        {lane: lanes[1], readings: lanes[1].series, glyph: "memory_alt", title: qsTr("Memory")},
        {lane: lanes[2], readings: lanes[2].series.map(periodReading), glyph: "hard_drive", title: qsTr("Disk I/O")},
        {lane: lanes[3], readings: lanes[3].series.map(periodReading), glyph: "lan", title: qsTr("Network")},
        {lane: lanes[4], readings: [lanes[4].series[0], periodReading(lanes[4].series[0])], glyph: "bolt", title: qsTr("Power")}
    ]
    Layout.minimumHeight: minimumContentHeight
    Layout.preferredHeight: minimumContentHeight

    FontMetrics {
        id: labelMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.metadataSize
    }
    FontMetrics {
        id: valueMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: overview.valueSize
        font.weight: Ui.Theme.fontWeightMedium
    }
    FontMetrics {
        id: headingMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: overview.headingSize
        font.weight: Ui.Theme.fontWeightMedium
    }
    function periodReading(descriptor: var): var {
        const energy = descriptor.kind === "power";
        return Object.assign({}, descriptor, {
            objectName: "resourceTotal_" + descriptor.metric,
            label: energy ? qsTr("Estimated CPU-package energy") : qsTr("Estimated %1 transferred").arg(descriptor.label),
            shortLabel: energy ? qsTr("Est. energy") : descriptor.shortLabel,
            available: !loading && Resources.measured(descriptor.periodValue),
            valueText: descriptor.periodText,
            color: energy ? Ui.Theme.mutedText : descriptor.color,
            plotted: !energy,
            detailText: qsTr("Selected period %1. Current %2. %3").arg(descriptor.observation).arg(descriptor.valueText).arg(descriptor.detailText)
        });
    }

    Rectangle {
        id: surface
        objectName: "applicationResourceList"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(overview.minimumContentHeight, overview.height)
        color: Ui.Theme.surface
        radius: Ui.Theme.cardRadius
        readonly property real rowHeight: (height - 2 * overview.contentPadding) / overview.rows.length
        Repeater {
            model: overview.rows.length
            delegate: ApplicationResourceRow {
                required property int index
                readonly property var modelData: overview.rows[index]
                objectName: "resourceRow_" + modelData.lane.id
                x: overview.contentPadding
                y: overview.contentPadding + index * surface.rowHeight
                width: Math.max(0, surface.width - 2 * overview.contentPadding)
                height: surface.rowHeight
                lane: modelData.lane
                readings: modelData.readings
                glyph: modelData.glyph
                title: modelData.title
                separatorVisible: index < overview.rows.length - 1
                readingWidth: overview.readingWidth
                labelWidth: overview.labelWidth
                valueSize: overview.valueSize
                headingSize: overview.headingSize
                columnGap: overview.rowGap
                points: overview.points
                rangeStartMilliseconds: overview.rangeStartMilliseconds
                rangeEndMilliseconds: overview.rangeEndMilliseconds
                loading: overview.loading
                active: overview.active
                uiScale: overview.uiScale
            }
        }
    }
}
