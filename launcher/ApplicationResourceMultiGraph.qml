import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Ui.ChartFrame {
    id: graph

    required property var points
    required property var series
    required property real uiScale
    property real minimumMaximum: 0
    property string chartStyle: "area"
    property bool available: true
    property double rangeStartMilliseconds: 0
    property double rangeEndMilliseconds: 0
    property double maximumGapMilliseconds: 30000

    readonly property var timestamps: (points || []).map(function (point) {
        const value = Number(point.timestamp_ms || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })
    readonly property double firstPointTimestamp: timestamps.reduce(function (current, value) {
        return value > 0 ? Math.min(current, value) : current;
    }, Number.MAX_VALUE)
    readonly property double lastPointTimestamp: timestamps.reduce(function (current, value) {
        return Math.max(current, value);
    }, 0)
    readonly property double firstTimestamp: rangeStartMilliseconds > 0
        ? rangeStartMilliseconds : firstPointTimestamp === Number.MAX_VALUE ? 0 : firstPointTimestamp
    readonly property double lastTimestamp: Math.max(firstTimestamp + 1,
        rangeEndMilliseconds > firstTimestamp ? rangeEndMilliseconds : lastPointTimestamp)
    readonly property real maximum: Math.max(minimumMaximum, 1, (points || []).reduce(function (largest, point) {
        return (series || []).reduce(function (seriesLargest, descriptor) {
            const average = Number(point[descriptor.metric]);
            const peak = Number((point.peaks || ({}))[descriptor.peakMetric || ""]);
            return Math.max(seriesLargest, isFinite(average) ? average : 0,
                isFinite(peak) ? peak : 0);
        }, largest);
    }, 0))
    readonly property int hoveredIndex: {
        if (!pointer.containsMouse || timestamps.length === 0)
            return -1;
        const target = firstTimestamp + pointer.mouseX / Math.max(1, pointer.width)
            * (lastTimestamp - firstTimestamp);
        let nearest = -1;
        let distance = Number.MAX_VALUE;
        timestamps.forEach(function (timestamp, index) {
            const nextDistance = Math.abs(timestamp - target);
            if (timestamp > 0 && nextDistance < distance) {
                nearest = index;
                distance = nextDistance;
            }
        });
        return nearest;
    }
    readonly property var hoveredPoint: hoveredIndex >= 0 ? points[hoveredIndex] : null

    graphHeight: Math.round(142 * uiScale)
    lineColor: series.length > 0 ? series[0].color : Ui.Theme.accent

    function formatValue(value, kind) {
        if (kind === "bytes") return Resources.bytes(value);
        if (kind === "rate") return Resources.rate(value);
        if (kind === "power") return Resources.power(value);
        if (kind === "count") return Resources.integer(value);
        if (kind === "ops") return Resources.operationsRate(value);
        if (kind === "faults") return Resources.decimal(value, 2) + "/s";
        return Resources.percent(value);
    }

    function tooltipText() {
        if (!hoveredPoint)
            return "";
        const rows = [new Date(hoveredPoint.timestamp_ms).toLocaleTimeString()];
        series.forEach(function (descriptor) {
            rows.push(descriptor.label + "  "
                + formatValue(hoveredPoint[descriptor.metric], descriptor.kind));
        });
        return rows.join("\n");
    }

    onPointsChanged: chart.requestPaint()
    onSeriesChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onFirstTimestampChanged: chart.requestPaint()
    onLastTimestampChanged: chart.requestPaint()
    onHoveredIndexChanged: chart.requestPaint()
    onRepaintRequested: chart.requestPaint()

    Canvas {
        id: chart
        anchors.fill: parent
        antialiasing: true

        function xFor(timestamp) {
            return (timestamp - graph.firstTimestamp)
                / Math.max(1, graph.lastTimestamp - graph.firstTimestamp) * width;
        }
        function yFor(value) {
            return height - Math.min(1, Math.max(0, value) / graph.maximum) * height;
        }
        function hatch(context, left, right) {
            const start = Math.max(0, left);
            const end = Math.min(width, right);
            if (end <= start)
                return;
            context.fillStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.055);
            context.fillRect(start, 0, end - start, height);
            context.save();
            context.beginPath();
            context.rect(start, 0, end - start, height);
            context.clip();
            context.beginPath();
            for (let x = start - height; x < end + height; x += 8) {
                context.moveTo(x, height);
                context.lineTo(x + height, 0);
            }
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.18);
            context.lineWidth = 1;
            context.stroke();
            context.restore();
        }
        function drawUnavailablePeriods(context) {
            if (!graph.available) {
                hatch(context, 0, width);
                return;
            }
            const valid = graph.timestamps.filter(function (timestamp) {
                return timestamp >= graph.firstTimestamp && timestamp <= graph.lastTimestamp;
            });
            const radius = graph.maximumGapMilliseconds / 2;
            if (valid.length === 0) {
                hatch(context, 0, width);
                return;
            }
            hatch(context, 0, xFor(Math.max(graph.firstTimestamp, valid[0] - radius)));
            for (let index = 1; index < valid.length; ++index) {
                if (valid[index] - valid[index - 1] > graph.maximumGapMilliseconds)
                    hatch(context, xFor(valid[index - 1] + radius), xFor(valid[index] - radius));
            }
            hatch(context, xFor(Math.min(graph.lastTimestamp, valid[valid.length - 1] + radius)), width);
        }
        function drawGrid(context) {
            context.beginPath();
            [0.25, 0.5, 0.75].forEach(function (fraction) {
                const y = height * fraction;
                context.moveTo(0, y);
                context.lineTo(width, y);
            });
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.border, 0.45);
            context.lineWidth = 1;
            context.stroke();
        }
        function segmentsFor(descriptor, peak) {
            const segments = [];
            let segment = [];
            let previousTimestamp = 0;
            graph.points.forEach(function (point, index) {
                const timestamp = graph.timestamps[index];
                const source = peak ? point.peaks || ({}) : point;
                const key = peak ? descriptor.peakMetric : descriptor.metric;
                const value = Number(source[key]);
                const valid = key && isFinite(value) && value >= 0 && timestamp >= graph.firstTimestamp
                    && timestamp <= graph.lastTimestamp;
                if (!valid || (previousTimestamp > 0
                        && timestamp - previousTimestamp > graph.maximumGapMilliseconds)) {
                    if (segment.length > 0) segments.push(segment);
                    segment = [];
                }
                if (valid) segment.push({ x: xFor(timestamp), y: yFor(value) });
                previousTimestamp = valid ? timestamp : 0;
            });
            if (segment.length > 0) segments.push(segment);
            return segments;
        }
        function drawBars(context) {
            const descriptors = graph.series || [];
            const bucketWidth = Math.max(1, graph.maximumGapMilliseconds
                / Math.max(1, graph.lastTimestamp - graph.firstTimestamp) * width);
            graph.points.forEach(function (point, pointIndex) {
                const timestamp = graph.timestamps[pointIndex];
                if (timestamp < graph.firstTimestamp || timestamp > graph.lastTimestamp)
                    return;
                const groupWidth = Math.max(1, bucketWidth * 0.82);
                const barWidth = Math.max(0.55, groupWidth / Math.max(1, descriptors.length));
                const groupLeft = xFor(timestamp) - groupWidth / 2;
                descriptors.forEach(function (descriptor, seriesIndex) {
                    const value = Number(point[descriptor.metric]);
                    if (!isFinite(value) || value < 0)
                        return;
                    const top = yFor(value);
                    context.fillStyle = Ui.Theme.withAlpha(descriptor.color, 0.78);
                    context.fillRect(groupLeft + seriesIndex * barWidth, top,
                        Math.max(0.55, barWidth - 0.4), height - top);
                });
            });
        }
        function drawSeries(context, descriptor, index) {
            const segments = segmentsFor(descriptor, false);
            segments.forEach(function (points) {
                if (graph.chartStyle === "area" && index === 0 && points.length > 1) {
                    context.beginPath();
                    context.moveTo(points[0].x, height);
                    points.forEach(function (point) { context.lineTo(point.x, point.y); });
                    context.lineTo(points[points.length - 1].x, height);
                    context.closePath();
                    const fill = context.createLinearGradient(0, 0, 0, height);
                    fill.addColorStop(0, Ui.Theme.withAlpha(descriptor.color, 0.22));
                    fill.addColorStop(1, Ui.Theme.withAlpha(descriptor.color, 0.01));
                    context.fillStyle = fill;
                    context.fill();
                }
                context.beginPath();
                points.forEach(function (point, pointIndex) {
                    if (pointIndex === 0) context.moveTo(point.x, point.y);
                    else context.lineTo(point.x, point.y);
                });
                context.setLineDash(descriptor.dashed ? [5, 4] : []);
                context.strokeStyle = descriptor.color;
                context.lineWidth = index === 0 ? 2 : 1.5;
                context.lineJoin = "round";
                context.lineCap = "round";
                context.stroke();
            });
            if (descriptor.peakMetric) {
                segmentsFor(descriptor, true).forEach(function (points) {
                    context.beginPath();
                    points.forEach(function (point, pointIndex) {
                        if (pointIndex === 0) context.moveTo(point.x, point.y);
                        else context.lineTo(point.x, point.y);
                    });
                    context.setLineDash([2, 3]);
                    context.strokeStyle = Ui.Theme.withAlpha(descriptor.color, 0.48);
                    context.lineWidth = 1;
                    context.stroke();
                });
            }
            context.setLineDash([]);
        }
        onPaint: {
            const context = getContext("2d");
            context.reset();
            drawUnavailablePeriods(context);
            drawGrid(context);
            if (!graph.available)
                return;
            if (graph.chartStyle === "bar")
                drawBars(context);
            else
                graph.series.forEach(function (descriptor, index) {
                    drawSeries(context, descriptor, index);
                });
            if (graph.hoveredIndex >= 0) {
                const x = xFor(graph.timestamps[graph.hoveredIndex]);
                context.beginPath();
                context.moveTo(x, 0);
                context.lineTo(x, height);
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.text, 0.45);
                context.lineWidth = 1;
                context.stroke();
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Rectangle {
        visible: graph.available && pointer.containsMouse && graph.hoveredPoint !== null
        x: Math.max(2, Math.min(parent.width - width - 2, pointer.mouseX + 10))
        y: 2
        width: tooltip.implicitWidth + 16
        height: tooltip.implicitHeight + 12
        radius: Ui.Theme.controlRadius
        color: Ui.Theme.withAlpha(Ui.Theme.window, 0.94)
        border.color: Ui.Theme.strongBorder
        border.width: 1

        Text {
            id: tooltip
            anchors.centerIn: parent
            text: graph.tooltipText()
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
}
