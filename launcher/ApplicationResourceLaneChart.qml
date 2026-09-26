pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Rectangle {
    id: chart

    required property string title
    required property var points
    required property var lanes
    property var summaries: ({})
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property double maximumGapMilliseconds: 30000
    property real uiScale: 1
    readonly property int plotLeft: Math.round(150 * uiScale)
    readonly property int plotRight: Math.round(12 * uiScale)
    readonly property var timestamps: (points || []).map(function (point) {
        const value = Number(point.timestamp_ms || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })

    function timeLabel(index) {
        if (index === 4)
            return "Now";
        const timestamp = rangeStartMilliseconds + (rangeEndMilliseconds - rangeStartMilliseconds) * index / 4;
        if (!isFinite(timestamp) || timestamp <= 0)
            return "--:--";
        return Qt.formatTime(new Date(timestamp), "HH:mm");
    }

    height: Math.round((48 + lanes.length * 64 + 30) * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.7)
    border.width: 0

    Ui.ThemeText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.topMargin: 11
        text: chart.title
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(42 * chart.uiScale)

        Repeater {
            model: chart.lanes
            delegate: Item {
                id: lane
                required property var modelData
                width: parent.width
                height: Math.round(64 * chart.uiScale)

                Ui.ChartValueRail {
                    x: 12
                    width: chart.plotLeft - 22
                    label: lane.modelData.label
                    valueText: lane.modelData.currentUnavailable ? "" : lane.modelData.valueText
                    referenceText: lane.modelData.currentUnavailable ? "No measurements" : lane.modelData.secondaryText || lane.modelData.referenceText || ""
                    valueColor: lane.modelData.color
                }

                Canvas {
                    id: plot
                    anchors.left: parent.left
                    anchors.leftMargin: chart.plotLeft
                    anchors.right: parent.right
                    anchors.rightMargin: chart.plotRight
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    antialiasing: true

                    function xFor(timestamp) {
                        return (timestamp - chart.rangeStartMilliseconds) / Math.max(1, chart.rangeEndMilliseconds - chart.rangeStartMilliseconds) * width;
                    }
                    function maximumFor(descriptors) {
                        const configured = Number(lane.modelData.maximum || 0);
                        if (configured > 0)
                            return configured;
                        const largest = descriptors.reduce(function (maximum, descriptor) {
                            return Math.max(maximum, Number((chart.summaries[descriptor.metric] || {}).peak || 0));
                        }, 0);
                        return Math.max(1, largest * 1.15);
                    }
                    function yFor(value, descriptorIndex, maximum) {
                        const fraction = Math.min(1, Math.max(0, value) / maximum);
                        if (lane.modelData.chartStyle === "paired") {
                            const centre = height / 2;
                            const direction = Number((lane.modelData.series[descriptorIndex] || ({})).direction || (descriptorIndex === 0 ? 1 : -1));
                            return direction > 0 ? centre - fraction * Math.max(1, centre - 3) : centre + fraction * Math.max(1, centre - 3);
                        }
                        return height - 3 - fraction * Math.max(1, height - 6);
                    }
                    function sampleAt(pointIndex, descriptor, descriptorIndex, maximum) {
                        const point = chart.points[pointIndex];
                        const timestamp = chart.timestamps[pointIndex];
                        const value = Number(point[descriptor.metric]);
                        const inRange = timestamp >= chart.rangeStartMilliseconds && timestamp <= chart.rangeEndMilliseconds;
                        if (!inRange || !isFinite(value) || value < 0 || !Resources.historicalMetricAvailable(point, descriptor.metric))
                            return null;
                        return {
                            timestamp: timestamp,
                            x: xFor(timestamp),
                            y: yFor(value, descriptorIndex, maximum)
                        };
                    }
                    // Unavailable samples and gaps longer than maximumGapMilliseconds break the line.
                    function validSegments(descriptor, descriptorIndex, maximum) {
                        const segments = [];
                        let previous = null;
                        chart.points.forEach(function (_point, pointIndex) {
                            const sample = sampleAt(pointIndex, descriptor, descriptorIndex, maximum);
                            if (sample && previous && sample.timestamp - previous.timestamp <= chart.maximumGapMilliseconds)
                                segments[segments.length - 1].push(sample);
                            else if (sample)
                                segments.push([sample]);
                            previous = sample;
                        });
                        return segments;
                    }
                    function dimRegion(context, left, right) {
                        const start = Math.max(0, left);
                        const end = Math.min(width, right);
                        if (end <= start)
                            return;
                        context.fillStyle = Ui.Theme.withAlpha(Ui.Theme.input, 0.38);
                        context.fillRect(start, 0, end - start, height);
                    }
                    function drawUnavailablePeriods(context) {
                        if (lane.modelData.unavailable) {
                            dimRegion(context, 0, width);
                            return;
                        }
                        // Dim unavailable buckets even when adjacent timestamps are close.
                        // Capability gaps must not be mistaken for measured zero activity.
                        let previousEnd = 0;
                        chart.points.forEach(function (point) {
                            const supported = (lane.modelData.series || []).some(function (descriptor) {
                                return Resources.historicalMetricAvailable(point, descriptor.metric);
                            });
                            if (!supported)
                                return;
                            const timestamp = Number(point.timestamp_ms);
                            const radius = Math.min(15000, Number(point.duration_ms) || 15000) / 2;
                            const left = Math.max(0, xFor(timestamp - radius));
                            const right = Math.min(width, xFor(timestamp + radius));
                            if (right <= 0 || left >= width)
                                return;
                            dimRegion(context, previousEnd, left);
                            previousEnd = Math.max(previousEnd, right);
                        });
                        dimRegion(context, previousEnd, width);
                    }
                    function drawTimeGuides(context) {
                        context.beginPath();
                        [0.25, 0.5, 0.75].forEach(function (fraction) {
                            const x = width * fraction;
                            context.moveTo(x, 0);
                            context.lineTo(x, height);
                        });
                        context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.border, 0.26);
                        context.lineWidth = 1;
                        context.stroke();
                    }
                    function descriptorValues(descriptor) {
                        const summary = chart.summaries[descriptor.metric] || {};
                        return {
                            average: Number(summary.mean || 0),
                            peak: Number(summary.peak || 0)
                        };
                    }
                    function drawReferences(context, descriptor, descriptorIndex, maximum) {
                        const values = descriptorValues(descriptor);
                        if (values.average <= 0 && values.peak <= 0)
                            return;
                        const averageY = yFor(values.average, descriptorIndex, maximum);
                        context.beginPath();
                        context.moveTo(0, averageY);
                        context.lineTo(width, averageY);
                        context.setLineDash([3, 5]);
                        context.strokeStyle = Ui.Theme.withAlpha(descriptor.color, 0.25);
                        context.lineWidth = 1;
                        context.stroke();
                        context.setLineDash([]);
                        const peakY = yFor(values.peak, descriptorIndex, maximum);
                        context.fillStyle = Ui.Theme.withAlpha(descriptor.color, 0.55);
                        context.fillRect(width - 7, peakY - 1, 7, 2);
                    }
                    function drawSeries(context, descriptor, descriptorIndex, maximum) {
                        const baseline = lane.modelData.chartStyle === "paired" ? height / 2 : height - 3;
                        let fill = Ui.Theme.withAlpha(descriptor.color, 0.12);
                        if (lane.modelData.chartStyle !== "paired") {
                            fill = context.createLinearGradient(0, height * 0.2, 0, baseline);
                            fill.addColorStop(0, Ui.Theme.withAlpha(descriptor.color, 0.2));
                            fill.addColorStop(1, Ui.Theme.withAlpha(descriptor.color, 0.025));
                        }
                        context.strokeStyle = descriptor.color;
                        context.lineWidth = 1.75;
                        context.lineJoin = "round";
                        context.lineCap = "round";
                        Ui.ChartDrawing.series(context, validSegments(descriptor, descriptorIndex, maximum), baseline, fill, false);
                    }
                    function drawBaseline(context) {
                        const y = lane.modelData.chartStyle === "paired" ? height / 2 : height - 3;
                        context.beginPath();
                        context.moveTo(0, y);
                        context.lineTo(width, y);
                        context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.22);
                        context.lineWidth = 1;
                        context.stroke();
                    }

                    Connections {
                        target: chart
                        function onPointsChanged() {
                            plot.requestPaint();
                        }
                        function onSummariesChanged() {
                            plot.requestPaint();
                        }
                        function onRangeStartMillisecondsChanged() {
                            plot.requestPaint();
                        }
                        function onRangeEndMillisecondsChanged() {
                            plot.requestPaint();
                        }
                    }

                    onPaint: {
                        const context = getContext("2d");
                        context.reset();
                        drawUnavailablePeriods(context);
                        drawTimeGuides(context);
                        drawBaseline(context);
                        if (lane.modelData.unavailable)
                            return;
                        const descriptors = lane.modelData.series || [];
                        const maximum = maximumFor(descriptors);
                        descriptors.forEach(function (descriptor, descriptorIndex) {
                            drawReferences(context, descriptor, descriptorIndex, maximum);
                            drawSeries(context, descriptor, descriptorIndex, maximum);
                        });
                    }
                }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.leftMargin: chart.plotLeft
        anchors.right: parent.right
        anchors.rightMargin: chart.plotRight
        anchors.bottom: parent.bottom
        height: Math.round(28 * chart.uiScale)

        Repeater {
            model: 5
            delegate: Ui.ThemeText {
                required property int index
                x: index === 0 ? 0 : index === 4 ? parent.width - width : parent.width * index / 4 - width / 2
                width: 48
                text: chart.timeLabel(index)
                color: index === 4 ? Ui.Theme.mutedText : Ui.Theme.subtleText
                horizontalAlignment: index === 0 ? Text.AlignLeft : index === 4 ? Text.AlignRight : Text.AlignHCenter
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: index === 4 ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
            }
        }
    }
}
