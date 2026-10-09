pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// Passive readings overlay the left of a full-card plot. All plots use the same
// time window; amounts, rates, utilization and power never share a vertical scale.
Rectangle {
    id: card

    required property var lane
    required property var readings
    required property var points
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property string glyph: ""
    property bool loading: false
    property bool active: true
    property real uiScale: 1
    readonly property real inset: Math.round(10 * uiScale)
    readonly property real readingGap: Math.round(3 * uiScale)
    property real valueSize: Math.max(Ui.Theme.formValueSize, Math.min(28, Math.floor((height - 2 * inset) * 0.20)))
    readonly property real glyphSize: Math.max(Ui.Theme.formValueSize, Math.round(valueSize * 0.85))
    readonly property bool hasHistory: lane.series.some(descriptor => Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds).length > 0)
    readonly property real maximum: maximumForSeries()
    // Observation durations remain in accessible summaries, not visual footers.
    readonly property string statusText: !loading && readings.some(reading => !reading.available) ? qsTr("Unavailable") : ""

    color: Ui.Theme.surfaceRaised
    radius: Ui.Theme.cardRadius
    // Explicit geometry from the grid, not content-sized minimums that make the
    // page taller than its viewport. Text keeps its readable minimum font size.
    implicitHeight: 0
    implicitWidth: 0
    Accessible.role: Accessible.StaticText
    Accessible.name: lane.accessibleText + ". " + qsTr("History scale 0 to %1. %2")
        .arg(Resources.formatted(maximum, lane.kind)).arg(lane.coverageText)

    function maximumForSeries(): real {
        if (lane.kind === "percent") return 100;
        let peak = 0;
        lane.series.forEach(descriptor => {
            if (Resources.measured(descriptor.peak)) peak = Math.max(peak, descriptor.peak);
            Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds)
                .forEach(segment => segment.forEach(interval => { peak = Math.max(peak, interval.value); }));
        });
        const value = Math.max(1, peak * 1.15);
        const step = Math.pow(10, Math.floor(Math.log(value) / Math.LN10));
        return Math.ceil(value / step) * step;
    }

    ApplicationResourcePlot {
        objectName: "resourcePlot_" + card.lane.id
        anchors.fill: parent
        anchors.margins: Math.round(4 * card.uiScale)
        visible: !card.loading && card.hasHistory
        points: card.loading ? [] : card.points
        series: card.lane.series
        chartStyle: card.lane.series.length > 1 ? "paired-columns" : "columns"
        maximum: card.maximum
        rangeStartMilliseconds: card.rangeStartMilliseconds
        rangeEndMilliseconds: card.rangeEndMilliseconds
        uiScale: card.uiScale
    }
    Ui.ContentState {
        objectName: "resourceContentState_" + card.lane.id
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.inset
        height: Math.max(0, card.height / 2 - card.inset)
        visible: card.loading || !card.hasHistory
        compact: true
        active: card.active
        icon: ""
        kind: card.loading ? "loading" : "empty"
        text: card.loading ? qsTr("Loading…") : qsTr("No history")
        uiScale: card.uiScale
    }
    // No layout column is reserved for readings: the plot continues underneath.
    // Every card has two readings at one shared scale. Narrow cards retain
    // readable text rather than squeezing a third, unrelated metric into power.
    ColumnLayout {
        objectName: "resourceOverlay_" + card.lane.id
        anchors.left: parent.left
        anchors.leftMargin: card.inset
        anchors.top: parent.top
        anchors.topMargin: card.inset
        width: Math.max(0, card.width - 2 * card.inset)
        height: Math.min(card.height - 2 * card.inset, 2 * card.valueSize * 1.25 + card.readingGap + Ui.Theme.metadataSize + 6)
        z: 1
        spacing: Math.round(4 * card.uiScale)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            spacing: Math.round(8 * card.uiScale)
            ApplicationResourceGlyph {
                visible: card.glyph.length > 0
                glyph: card.glyph
                uiScale: card.glyphSize / 20
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                spacing: card.readingGap
                Repeater {
                    model: card.readings.length
                    delegate: ApplicationResourceCapacity {
                        required property int index
                        descriptor: card.readings[index]
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        Layout.preferredHeight: 1
                        alignRight: false
                        overChart: true
                        fitToSlot: true
                        uiScale: card.uiScale
                        glyphSize: card.glyphSize
                        valueSize: card.valueSize
                        showUnavailableReason: false
                    }
                }
            }
        }
        Ui.ThemeText {
            objectName: "resourceStatus_" + card.lane.id
            Layout.fillWidth: true
            Layout.minimumHeight: Ui.Theme.metadataSize + 2
            Layout.preferredHeight: Ui.Theme.metadataSize + 2
            Layout.maximumHeight: Ui.Theme.metadataSize + 2
            text: card.statusText
            font.pixelSize: Ui.Theme.metadataSize
            color: Ui.Theme.mutedText
            style: Text.Outline
            styleColor: card.color
            wrapMode: Text.Wrap
        }
    }
}
