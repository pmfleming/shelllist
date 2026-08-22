pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: chart

    required property string title
    required property var points
    required property var lanes
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
        const timestamp = rangeStartMilliseconds
            + (rangeEndMilliseconds - rangeStartMilliseconds) * index / 4;
        if (!isFinite(timestamp) || timestamp <= 0)
            return "--:--";
        return Qt.formatTime(new Date(timestamp), "HH:mm");
    }

    height: Math.round((48 + lanes.length * 64 + 30) * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.7)
    border.width: 0

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.topMargin: 11
        text: chart.title
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    width: chart.plotLeft - 22
                    text: lane.modelData.label
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightDemiBold
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    width: chart.plotLeft - 22
                    text: lane.modelData.unavailable ? "" : lane.modelData.valueText
                    color: lane.modelData.color
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeBody
                    font.weight: Ui.Theme.fontWeightBold
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 39
                    width: chart.plotLeft - 22
                    text: lane.modelData.unavailable ? "No measurements"
                        : lane.modelData.secondaryText || lane.modelData.referenceText || ""
                    color: Ui.Theme.subtleText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
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
                        return (timestamp - chart.rangeStartMilliseconds)
                            / Math.max(1, chart.rangeEndMilliseconds - chart.rangeStartMilliseconds) * width;
                    }
                    function maximumFor(descriptors) {
                        const configured = Number(lane.modelData.maximum || 0);
                        if (configured > 0)
                            return configured;
                        const largest = chart.points.reduce(function (current, point) {
                            return descriptors.reduce(function (next, descriptor) {
                                const average = Number(point[descriptor.metric]);
                                const peak = Number((point.peaks || ({}))[descriptor.peakMetric || ""]);
                                return Math.max(next, isFinite(average) ? average : 0,
                                    isFinite(peak) ? peak : 0);
                            }, current);
                        }, 0);
                        return Math.max(1, largest * 1.15);
                    }
                    function yFor(value, descriptorIndex, maximum) {
                        const fraction = Math.min(1, Math.max(0, value) / maximum);
                        if (lane.modelData.chartStyle === "paired") {
                            const centre = height / 2;
                            const direction = Number((lane.modelData.series[descriptorIndex] || ({})).direction
                                || (descriptorIndex === 0 ? 1 : -1));
                            return direction > 0
                                ? centre - fraction * Math.max(1, centre - 3)
                                : centre + fraction * Math.max(1, centre - 3);
                        }
                        return height - 3 - fraction * Math.max(1, height - 6);
                    }
                    function validSegments(descriptor, descriptorIndex, maximum) {
                        const segments = [];
                        let segment = [];
                        let previousTimestamp = 0;
                        chart.points.forEach(function (point, pointIndex) {
                            const timestamp = chart.timestamps[pointIndex];
                            const value = Number(point[descriptor.metric]);
                            const valid = isFinite(value) && value >= 0
                                && timestamp >= chart.rangeStartMilliseconds
                                && timestamp <= chart.rangeEndMilliseconds;
                            if (!valid || (previousTimestamp > 0
                                    && timestamp - previousTimestamp > chart.maximumGapMilliseconds)) {
                                if (segment.length > 0)
                                    segments.push(segment);
                                segment = [];
                            }
                            if (valid)
                                segment.push({ x: xFor(timestamp),
                                    y: yFor(value, descriptorIndex, maximum) });
                            previousTimestamp = valid ? timestamp : 0;
                        });
                        if (segment.length > 0)
                            segments.push(segment);
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
                        const valid = chart.timestamps.filter(function (timestamp) {
                            return timestamp >= chart.rangeStartMilliseconds
                                && timestamp <= chart.rangeEndMilliseconds;
                        });
                        if (valid.length === 0) {
                            dimRegion(context, 0, width);
                            return;
                        }
                        const radius = chart.maximumGapMilliseconds / 2;
                        dimRegion(context, 0, xFor(Math.max(chart.rangeStartMilliseconds,
                            valid[0] - radius)));
                        for (let index = 1; index < valid.length; ++index) {
                            if (valid[index] - valid[index - 1] > chart.maximumGapMilliseconds)
                                dimRegion(context, xFor(valid[index - 1] + radius),
                                    xFor(valid[index] - radius));
                        }
                        dimRegion(context, xFor(Math.min(chart.rangeEndMilliseconds,
                            valid[valid.length - 1] + radius)), width);
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
                        const values = [];
                        let peak = 0;
                        chart.points.forEach(function (point) {
                            const value = Number(point[descriptor.metric]);
                            if (isFinite(value) && value >= 0)
                                values.push(value);
                            const bucketPeak = Number((point.peaks || ({}))[descriptor.peakMetric || ""]);
                            if (isFinite(bucketPeak))
                                peak = Math.max(peak, bucketPeak);
                        });
                        const average = values.length > 0 ? values.reduce(function (sum, value) {
                            return sum + value;
                        }, 0) / values.length : 0;
                        return { average: average, peak: Math.max(peak,
                            values.reduce(function (largest, value) { return Math.max(largest, value); }, 0)) };
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
                        validSegments(descriptor, descriptorIndex, maximum).forEach(function (points) {
                            if (points.length > 1) {
                                context.beginPath();
                                context.moveTo(points[0].x, baseline);
                                points.forEach(function (point) { context.lineTo(point.x, point.y); });
                                context.lineTo(points[points.length - 1].x, baseline);
                                context.closePath();
                                if (lane.modelData.chartStyle === "paired") {
                                    context.fillStyle = Ui.Theme.withAlpha(descriptor.color, 0.12);
                                } else {
                                    const fill = context.createLinearGradient(0, height * 0.2,
                                        0, baseline);
                                    fill.addColorStop(0, Ui.Theme.withAlpha(descriptor.color, 0.2));
                                    fill.addColorStop(1, Ui.Theme.withAlpha(descriptor.color, 0.025));
                                    context.fillStyle = fill;
                                }
                                context.fill();
                            }
                            context.beginPath();
                            points.forEach(function (point, pointIndex) {
                                if (pointIndex === 0)
                                    context.moveTo(point.x, point.y);
                                else
                                    context.lineTo(point.x, point.y);
                            });
                            context.strokeStyle = descriptor.color;
                            context.lineWidth = 1.75;
                            context.lineJoin = "round";
                            context.lineCap = "round";
                            context.stroke();
                        });
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
                        function onPointsChanged() { plot.requestPaint(); }
                        function onRangeStartMillisecondsChanged() { plot.requestPaint(); }
                        function onRangeEndMillisecondsChanged() { plot.requestPaint(); }
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
            delegate: Text {
                required property int index
                x: index === 0 ? 0 : index === 4 ? parent.width - width
                    : parent.width * index / 4 - width / 2
                width: 48
                text: chart.timeLabel(index)
                color: index === 4 ? Ui.Theme.mutedText : Ui.Theme.subtleText
                horizontalAlignment: index === 0 ? Text.AlignLeft
                    : index === 4 ? Text.AlignRight : Text.AlignHCenter
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: index === 4 ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
            }
        }
    }
}
