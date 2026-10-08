pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// A passive, viewport-sized reading/history pair. All plots use the same time
// window; amounts, rates, utilization and power never share a vertical scale.
Rectangle {
    id: card

    required property var lane
    required property var readings
    required property var points
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property var footprint: null
    property string glyph: ""
    property bool loading: false
    property bool active: true
    property real uiScale: 1
    readonly property real inset: Math.round(10 * uiScale)
    readonly property bool hasHistory: lane.series.some(descriptor => Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds).length > 0)
    readonly property real maximum: maximumForSeries()
    readonly property string partialCoverage: lane.series.filter(descriptor => Resources.measured(descriptor.observedMs)
        && descriptor.observedMs < rangeEndMilliseconds - rangeStartMilliseconds)
        .map(descriptor => descriptor.shortLabel + " " + descriptor.coverage).join(" · ")
    readonly property string statusText: [
        !loading && (readings.some(reading => !reading.available) || (footprint && !footprint.available)) ? qsTr("Unavailable") : "",
        !loading && partialCoverage.length > 0 ? "◷ " + partialCoverage : ""
    ].filter(text => text.length > 0).join(" · ")

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.inset
        spacing: Math.round(4 * card.uiScale)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            spacing: Math.round(8 * card.uiScale)

            ApplicationResourceGlyph {
                visible: card.glyph.length > 0
                glyph: card.glyph
                uiScale: card.uiScale * 0.8
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                Layout.preferredWidth: Math.min(implicitWidth, card.width * (card.footprint ? 0.25 : 0.48))
                Layout.maximumWidth: card.width * (card.footprint ? 0.25 : 0.48)
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(8 * card.uiScale)
                Repeater {
                    model: card.readings.length
                    delegate: ApplicationResourceCapacity {
                        required property int index
                        descriptor: card.readings[index]
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        alignRight: false
                        uiScale: card.uiScale * 0.8
                        valueSize: Math.round(15 * card.uiScale)
                        showUnavailableReason: false
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                ApplicationResourcePlot {
                    objectName: "resourcePlot_" + card.lane.id
                    anchors.fill: parent
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
                    anchors.fill: parent
                    visible: card.loading || !card.hasHistory
                    compact: true
                    active: card.active
                    // Text-only compact state fits a microplot without clipping a
                    // large decorative glyph. It remains the shared state owner.
                    icon: ""
                    kind: card.loading ? "loading" : "empty"
                    text: card.loading ? qsTr("Loading…") : qsTr("No history")
                    uiScale: card.uiScale
                }
            }
            ApplicationResourceCapacity {
                visible: card.footprint !== null
                descriptor: card.footprint || ({objectName: "", label: "", detailText: "", valueText: "", available: false, color: Ui.Theme.mutedText, icon: "folder"})
                Layout.maximumWidth: card.width * 0.24
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                alignRight: false
                uiScale: card.uiScale * 0.8
                valueSize: Math.round(13 * card.uiScale)
                showUnavailableReason: false
            }
        }
        Ui.ThemeText {
            objectName: "resourceCoverage_" + card.lane.id
            Layout.fillWidth: true
            visible: card.statusText.length > 0
            text: card.statusText
            font.pixelSize: Ui.Theme.fontSizeCaption
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
        }
    }
}
