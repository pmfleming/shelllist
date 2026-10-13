pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// Readings and history have separate slots. Each row owns a vertical scale;
// all rows share one time window and the axis below the list.
Item {
    id: row
    required property var lane
    required property var readings
    required property var points
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    required property string glyph
    required property string title
    required property real readingWidth
    required property real labelWidth
    required property real valueSize
    required property real headingSize
    required property real columnGap
    property bool separatorVisible: true
    property bool loading: false
    property bool active: true
    property real uiScale: 1
    readonly property bool hasHistory: lane.series.some(descriptor => Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds).length > 0)
    readonly property real maximum: maximumForSeries()
    readonly property string statusText: !loading && readings.some(reading => !reading.available) ? qsTr("Unavailable") : ""
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
        objectName: "resourceReadings_" + row.lane.id
        x: 0
        y: Ui.Theme.spacingXs
        width: row.readingWidth
        spacing: Ui.Theme.spacingXs
        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            ApplicationResourceGlyph {
                glyph: row.glyph
                color: Ui.Theme.mutedText
                uiScale: Ui.Theme.iconSize / 20
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: row.title
                font.pixelSize: row.headingSize
                font.weight: Ui.Theme.fontWeightMedium
                elide: Text.ElideRight
            }
        }
        Repeater {
            model: row.readings.length
            delegate: ApplicationResourceCapacity {
                required property int index
                descriptor: row.readings[index]
                secondary: index === 1
                labelWidth: row.labelWidth
                valueSize: row.valueSize
                Layout.fillWidth: true
            }
        }
    }
    ColumnLayout {
        objectName: "resourceGraphSlot_" + row.lane.id
        x: row.readingWidth + row.columnGap
        y: Ui.Theme.spacingXs
        width: Math.max(0, row.width - x)
        height: Math.max(0, row.height - 2 * Ui.Theme.spacingXs)
        spacing: Ui.Theme.spacingXs
        Ui.ThemeText {
            objectName: "resourceScale_" + row.lane.id
            Layout.fillWidth: true
            text: qsTr("0–%1").arg(row.lane.kind === "percent" ? "100%" : Resources.formatted(row.maximum, row.lane.kind))
            font.pixelSize: Ui.Theme.fontSizeCaption
            color: Ui.Theme.mutedText
            horizontalAlignment: Text.AlignRight
            Accessible.ignored: true
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Ui.Theme.spacingLg
            ApplicationResourcePlot {
                objectName: "resourcePlot_" + row.lane.id
                anchors.fill: parent
                visible: !row.loading && row.hasHistory
                points: row.loading ? [] : row.points
                series: row.lane.series
                chartStyle: row.lane.kind === "bytes" ? "steps" : row.lane.kind === "percent" ? "lines"
                    : row.lane.series.length > 1 ? "paired-columns" : "columns"
                maximum: row.maximum
                rangeStartMilliseconds: row.rangeStartMilliseconds
                rangeEndMilliseconds: row.rangeEndMilliseconds
                uiScale: row.uiScale
            }
            Ui.ContentState {
                objectName: "resourceContentState_" + row.lane.id
                anchors.fill: parent
                visible: row.loading || !row.hasHistory
                compact: true
                active: row.active
                icon: ""
                kind: row.loading ? "loading" : "empty"
                text: row.loading ? qsTr("Loading…") : row.statusText || qsTr("No history")
                uiScale: row.uiScale
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        visible: row.separatorVisible
        color: Ui.Theme.border
        Accessible.ignored: true
    }
}
