pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

ColumnLayout {
    id: chart

    required property var points
    required property var lanes
    required property var footprint
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property bool loading: false
    property bool active: true
    property real uiScale: 1
    readonly property bool wide: width >= 480 * uiScale
    readonly property real valueWidth: Math.round(155 * uiScale)
    readonly property real inset: Math.round(8 * uiScale)
    spacing: Math.round(7 * uiScale)

    function timeLabel(index: int): string {
        const timestamp = rangeStartMilliseconds + (rangeEndMilliseconds - rangeStartMilliseconds) * index / 4;
        return isFinite(timestamp) && timestamp > 0 ? Qt.formatTime(new Date(timestamp), "HH:mm") : "--:--";
    }

    Repeater {
        model: chart.lanes
        delegate: Rectangle {
            id: lane
            required property var modelData
            objectName: "resourceGroup_" + modelData.id
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + 2 * chart.inset
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surface
            readonly property bool hasHistory: modelData.series.some(descriptor => Resources.historySegments(chart.points, descriptor.metric, chart.rangeStartMilliseconds, chart.rangeEndMilliseconds).length > 0)
            readonly property bool hasCurrent: modelData.series.some(descriptor => descriptor.available)
            readonly property real maximum: {
                let peak = 0;
                modelData.series.forEach(descriptor => {
                    if (Resources.measured(descriptor.peak)) peak = Math.max(peak, descriptor.peak);
                    Resources.historySegments(chart.points, descriptor.metric, chart.rangeStartMilliseconds, chart.rangeEndMilliseconds).forEach(segment => segment.forEach(interval => { peak = Math.max(peak, interval.value); }));
                });
                const value = Math.max(modelData.kind === "power" ? 0.01 : 1, peak * 1.15);
                const step = Math.pow(10, Math.floor(Math.log(value) / Math.LN10));
                return Math.ceil(value / step) * step;
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.accessibleText

            ColumnLayout {
                id: content
                x: chart.inset
                y: chart.inset
                width: lane.width - 2 * chart.inset
                spacing: Math.round(4 * chart.uiScale)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Ui.Theme.spacingSm
                    Ui.GlyphLabel {
                        glyph: lane.modelData.icon
                        color: lane.modelData.series[0].color
                        font.pixelSize: Ui.Theme.iconSizeSmall
                        Accessible.ignored: true
                    }
                    Ui.ThemeText {
                        text: lane.modelData.label
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: lane.modelData.qualifier
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.Wrap
                    }
                }
                ColumnLayout {
                    objectName: lane.modelData.id === "storage" ? "applicationDiskFootprint" : ""
                    visible: lane.modelData.id === "storage"
                    Layout.fillWidth: true
                    property string valueText: chart.footprint.valueText
                    property bool available: chart.footprint.available
                    property string detailText: chart.footprint.detailText
                    spacing: Math.round(4 * chart.uiScale)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("Identified app data, not the complete installation: %1. %2").arg(valueText).arg(detailText)
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.ThemeText {
                            text: qsTr("App data")
                            font.pixelSize: Ui.Theme.fontSizeCaption
                            color: Ui.Theme.mutedText
                        }
                        Ui.ThemeText {
                            objectName: "resourceValue"
                            text: chart.footprint.available ? chart.footprint.valueText : "—"
                            color: Ui.Theme.resourceDisk
                            font.weight: Ui.Theme.fontWeightDemiBold
                            wrapMode: Text.Wrap
                            Layout.fillWidth: !chart.wide
                        }
                        Rectangle {
                            objectName: lane.modelData.id === "storage" ? "applicationDiskComposition" : ""
                            visible: chart.wide
                            Layout.fillWidth: true
                            Layout.minimumWidth: 20
                            implicitHeight: Math.round(6 * chart.uiScale)
                            radius: height / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Ui.Theme.border
                            readonly property real total: chart.footprint.permanent + chart.footprint.temporary
                            readonly property real fraction: total > 0 && chart.footprint.compositionAvailable ? chart.footprint.permanent / total : 0
                            Rectangle {
                                width: parent.width * parent.fraction
                                height: parent.height
                                color: Ui.Theme.resourceDisk
                            }
                            Rectangle {
                                x: parent.width * parent.fraction
                                width: chart.footprint.compositionAvailable && parent.total > 0 ? parent.width - x : 0
                                height: parent.height
                                color: Ui.Theme.resourceGpu
                            }
                            Accessible.ignored: true
                        }
                        Ui.ThemeText {
                            Layout.maximumWidth: content.width * 0.45
                            text: qsTr("Installation not measured")
                            color: Ui.Theme.mutedText
                            font.pixelSize: Ui.Theme.fontSizeCaption
                            wrapMode: Text.Wrap
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: chart.wide ? 2 : 1
                    columnSpacing: Ui.Theme.spacingMd
                    rowSpacing: Math.round(4 * chart.uiScale)
                    visible: lane.hasCurrent || lane.hasHistory || chart.loading
                    ColumnLayout {
                        Layout.fillWidth: !chart.wide
                        Layout.preferredWidth: chart.wide ? chart.valueWidth : -1
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(2 * chart.uiScale)
                        Repeater {
                            model: lane.modelData.series
                            delegate: ApplicationResourceCapacity {
                                required property var modelData
                                objectName: modelData.objectName
                                Layout.fillWidth: true
                                label: modelData.shortLabel
                                accessibleLabel: modelData.label
                                valueText: modelData.valueText
                                available: modelData.available
                                detailText: modelData.detailText
                                accentColor: modelData.color
                                uiScale: chart.uiScale
                            }
                        }
                        ApplicationResourceCapacity {
                            objectName: lane.modelData.id === "energy" ? "applicationPeriodEnergy" : ""
                            visible: lane.modelData.id === "energy"
                            Layout.fillWidth: true
                            label: lane.modelData.rangeLabel
                            accessibleLabel: qsTr("Estimated energy over %1").arg(lane.modelData.rangeLabel)
                            valueText: lane.modelData.periodText
                            available: chart.loading || lane.modelData.periodAvailable
                            detailText: lane.modelData.coverageText
                            accentColor: Ui.Theme.resourcePower
                            uiScale: chart.uiScale
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Math.round(3 * chart.uiScale)
                        RowLayout {
                            Layout.fillWidth: true
                            Ui.ThemeText {
                                Layout.fillWidth: true
                                text: chart.loading ? qsTr("Loading…") : !lane.hasHistory ? qsTr("No observed intervals")
                                    : (lane.modelData.style === "columns" || lane.modelData.style === "paired-area" ? "±" : "0 – ") + Resources.formatted(lane.maximum, lane.modelData.kind)
                                        + (lane.modelData.style === "lines" || lane.modelData.style === "steps" ? qsTr(" · GPU ┄") : "")
                                color: Ui.Theme.mutedText
                                font.pixelSize: Ui.Theme.fontSizeCaption
                                wrapMode: Text.Wrap
                            }
                            Ui.ThemeText {
                                objectName: "resourceCoverage_" + lane.modelData.id
                                Layout.maximumWidth: content.width * (chart.wide ? 0.3 : 0.5)
                                visible: !chart.loading
                                text: "◷ " + lane.modelData.coverageText
                                color: Ui.Theme.mutedText
                                font.pixelSize: Ui.Theme.fontSizeCaption
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.Wrap
                            }
                        }
                        ApplicationResourcePlot {
                            objectName: "resourcePlot_" + lane.modelData.id
                            Layout.fillWidth: true
                            visible: lane.hasHistory
                            points: chart.points
                            series: lane.modelData.series
                            chartStyle: lane.modelData.style
                            maximum: lane.maximum
                            rangeStartMilliseconds: chart.rangeStartMilliseconds
                            rangeEndMilliseconds: chart.rangeEndMilliseconds
                            uiScale: chart.uiScale
                        }
                    }
                }
                Ui.ContentState {
                    objectName: "resourceContentState_" + lane.modelData.id
                    Layout.fillWidth: true
                    visible: !lane.hasHistory
                    compact: true
                    active: chart.active
                    icon: "history"
                    kind: chart.loading ? "loading" : "empty"
                    text: chart.loading ? qsTr("Reading resource history…") : lane.modelData.unavailableText || qsTr("No retained history")
                    uiScale: chart.uiScale
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    visible: lane.hasHistory && !chart.loading && lane.modelData.unavailableText.length > 0
                    text: lane.modelData.unavailableText
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    wrapMode: Text.Wrap
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    visible: lane.modelData.id === "storage" || lane.modelData.id === "network"
                    text: chart.loading ? qsTr("Loading period totals…") : lane.modelData.rangeLabel + " · " + lane.modelData.periodText
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    wrapMode: Text.Wrap
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: chart.wide ? chart.inset + chart.valueWidth + Ui.Theme.spacingMd : chart.inset
        Layout.rightMargin: chart.inset
        Repeater {
            model: 3
            delegate: Ui.ThemeText {
                required property int index
                Layout.fillWidth: true
                text: chart.timeLabel(index * 2)
                horizontalAlignment: index === 0 ? Text.AlignLeft : index === 2 ? Text.AlignRight : Text.AlignHCenter
                font.pixelSize: Ui.Theme.fontSizeCaption
                color: Ui.Theme.mutedText
            }
        }
    }
}
