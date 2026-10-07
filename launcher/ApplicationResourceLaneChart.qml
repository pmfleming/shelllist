pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

ColumnLayout {
    id: chart
    required property var points
    required property var lanes
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property bool loading: false
    property bool active: true
    property real uiScale: 1
    readonly property bool wide: width >= 560 * uiScale
    readonly property real plotInset: Math.round(35 * uiScale)
    spacing: Math.round(12 * uiScale)

    function maximumFor(descriptors: var): real {
        let peak = 0;
        descriptors.forEach(descriptor => {
            if (Resources.measured(descriptor.peak)) peak = Math.max(peak, descriptor.peak);
            Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds).forEach(segment => segment.forEach(interval => { peak = Math.max(peak, interval.value); }));
        });
        const value = Math.max(1, peak * 1.15);
        const step = Math.pow(10, Math.floor(Math.log(value) / Math.LN10));
        return Math.ceil(value / step) * step;
    }

    ColumnLayout {
        objectName: "resourceGroup_activity"
        Layout.fillWidth: true
        spacing: Math.round(8 * chart.uiScale)
        Repeater {
            model: chart.lanes[0].series
            delegate: ApplicationResourceHistoryLane {
                required property var modelData
                Layout.fillWidth: true
                descriptor: modelData
                points: chart.points
                maximum: chart.maximumFor(chart.lanes[0].series)
                chartStyle: "columns"
                rangeStartMilliseconds: chart.rangeStartMilliseconds
                rangeEndMilliseconds: chart.rangeEndMilliseconds
                loading: chart.loading
                active: chart.active
                uiScale: chart.uiScale
            }
        }
        ApplicationResourceTimeAxis {
            Layout.fillWidth: true
            Layout.leftMargin: chart.plotInset
            rangeStartMilliseconds: chart.rangeStartMilliseconds
            rangeEndMilliseconds: chart.rangeEndMilliseconds
        }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.border }
    ColumnLayout {
        objectName: "resourceGroup_memory"
        Layout.fillWidth: true
        spacing: Math.round(6 * chart.uiScale)
        Ui.ThemeText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "0 – " + Resources.bytes(chart.maximumFor([chart.lanes[1].series[0]]))
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        ApplicationResourceHistoryLane {
            Layout.fillWidth: true
            descriptor: chart.lanes[1].series[0]
            points: chart.points
            maximum: chart.maximumFor([chart.lanes[1].series[0]])
            chartStyle: "steps"
            rangeStartMilliseconds: chart.rangeStartMilliseconds
            rangeEndMilliseconds: chart.rangeEndMilliseconds
            loading: chart.loading
            active: chart.active
            uiScale: chart.uiScale
        }
        ApplicationResourceTimeAxis {
            Layout.fillWidth: true
            Layout.leftMargin: chart.plotInset
            rangeStartMilliseconds: chart.rangeStartMilliseconds
            rangeEndMilliseconds: chart.rangeEndMilliseconds
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: chart.wide ? 2 : 1
        columnSpacing: Math.round(12 * chart.uiScale)
        rowSpacing: columnSpacing
        Ui.DetailColumnCard {
            id: disk
            objectName: "resourceGroup_storage"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            contentPadding: Math.round(12 * chart.uiScale)
            verticalContentPadding: Math.round(12 * chart.uiScale)
            readonly property var lane: chart.lanes[2]
            readonly property bool hasHistory: lane.series.some(descriptor => Resources.historySegments(chart.points, descriptor.metric, chart.rangeStartMilliseconds, chart.rangeEndMilliseconds).length > 0)
            readonly property real maximum: chart.maximumFor(lane.series)
            Accessible.role: Accessible.StaticText
            Accessible.name: lane.accessibleText + ". " + qsTr("Read left, write right. Scale 0 to %1.").arg(Resources.rate(maximum))
            RowLayout {
                Layout.fillWidth: true
                ApplicationResourceGlyph { glyph: "hard_drive"; color: Ui.Theme.resourceDisk; uiScale: chart.uiScale }
                Ui.ThemeText { Layout.fillWidth: true; text: qsTr("Disk I/O"); wrapMode: Text.Wrap; font.weight: Ui.Theme.fontWeightDemiBold }
            }
            RowLayout {
                Layout.fillWidth: true
                Ui.ThemeText { text: qsTr("↓ R / ↑ W"); color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.fontSizeCaption }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "0 – " + Resources.rate(disk.maximum)
                    wrapMode: Text.Wrap
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
            ApplicationResourcePlot {
                objectName: "resourcePlot_storage"
                Layout.fillWidth: true
                visible: !chart.loading && disk.hasHistory
                points: chart.points
                series: disk.lane.series
                chartStyle: "paired-columns"
                maximum: disk.maximum
                rangeStartMilliseconds: chart.rangeStartMilliseconds
                rangeEndMilliseconds: chart.rangeEndMilliseconds
                uiScale: chart.uiScale
            }
            Ui.ContentState {
                objectName: "resourceContentState_storage"
                Layout.fillWidth: true
                visible: chart.loading || !disk.hasHistory
                compact: true
                active: chart.active
                icon: "storage"
                kind: chart.loading ? "loading" : "empty"
                text: chart.loading ? qsTr("Reading disk history…") : qsTr("No retained disk history")
                uiScale: chart.uiScale
            }
            ApplicationResourceTimeAxis {
                Layout.fillWidth: true
                rangeStartMilliseconds: chart.rangeStartMilliseconds
                rangeEndMilliseconds: chart.rangeEndMilliseconds
            }
        }
        ApplicationResourceTransferTotals {
            objectName: "resourceGroup_network"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            lane: chart.lanes[3]
            loading: chart.loading
            uiScale: chart.uiScale
        }
    }
    Ui.ThemeText {
        objectName: "resourceCoverage_activity_storage"
        Layout.fillWidth: true
        visible: !chart.loading
        text: chart.lanes[0].coverageText === chart.lanes[2].coverageText
            ? qsTr("◷ Activity / I/O %1").arg(chart.lanes[0].coverageText)
            : qsTr("◷ Activity %1 · I/O %2").arg(chart.lanes[0].coverageText).arg(chart.lanes[2].coverageText)
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
