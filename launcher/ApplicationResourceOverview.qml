pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// The information boundary excludes every glyph, value and chart from field
// traversal. The range selector outside this section is the only editor.
Ui.DetailSection {
    id: overview
    informationOnly: true
    required property var lanes
    required property var footprint
    required property var points
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    required property real uiScale
    property bool loading: false
    property bool active: true
    readonly property var cards: [
        {lane: lanes[0], readings: lanes[0].series, glyph: ""},
        {lane: lanes[1], readings: lanes[1].series, glyph: ""},
        {lane: lanes[2], readings: lanes[2].series.map(periodReading), glyph: "hard_drive"},
        {lane: lanes[3], readings: lanes[3].series.map(periodReading), glyph: "lan"},
        {lane: lanes[4], readings: [lanes[4].series[0], periodReading(lanes[4].series[0])], glyph: ""}
    ]
    Layout.minimumHeight: 0
    Layout.preferredHeight: 1

    function periodReading(descriptor: var): var {
        const energy = descriptor.kind === "power";
        return Object.assign({}, descriptor, {
            objectName: "resourceTotal_" + descriptor.metric,
            label: energy ? qsTr("Estimated CPU-package energy") : qsTr("%1 transferred").arg(descriptor.label),
            icon: energy ? "functions" : descriptor.icon,
            available: !loading && Resources.measured(descriptor.periodValue),
            valueText: descriptor.periodText,
            detailText: qsTr("Selected period %1. Current %2. %3").arg(descriptor.observation).arg(descriptor.valueText).arg(descriptor.detailText)
        });
    }

    GridLayout {
        objectName: "applicationResourceCards"
        Layout.fillWidth: true
        Layout.preferredHeight: overview.height
        columns: 2
        uniformCellHeights: true
        columnSpacing: Math.round(8 * overview.uiScale)
        rowSpacing: columnSpacing
        Repeater {
            model: overview.cards.length
            delegate: ApplicationResourceMicrocard {
                required property int index
                readonly property var modelData: overview.cards[index]
                objectName: "resourceCard_" + modelData.lane.id
                Layout.columnSpan: index === 4 ? 2 : 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                lane: modelData.lane
                readings: modelData.readings
                glyph: modelData.glyph
                footprint: index === 4 ? overview.footprint.reading : null
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
