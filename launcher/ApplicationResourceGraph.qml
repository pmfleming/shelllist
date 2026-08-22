import QtQuick
import Shelllist.Ui as Ui

Ui.ChartFrame {
    id: graph

    required property var points
    required property real uiScale
    property string metric: "cpu_percent_of_machine"
    property string peakMetric: metric
    property real minimumMaximum: 0
    property double rangeStartMilliseconds: 0
    property double rangeEndMilliseconds: 0
    property double maximumGapMilliseconds: 30000

    readonly property var values: (points || []).map(function (point) {
        const value = Number(point[metric] || 0);
        return isFinite(value) && value >= 0 ? value : null;
    })
    readonly property var peakValues: (points || []).map(function (point) {
        const peaks = point.peaks || ({});
        const value = Number(peaks[peakMetric]);
        return isFinite(value) && value >= 0 ? value : null;
    })
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
    readonly property real maximum: Math.max(minimumMaximum, 1,
        values.concat(peakValues).reduce(function (current, value) {
            return value === null ? current : Math.max(current, value);
        }, 0))

    graphHeight: Math.round(82 * uiScale)
    onValuesChanged: chart.requestPaint()
    onPeakValuesChanged: chart.requestPaint()
    onTimestampsChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onFirstTimestampChanged: chart.requestPaint()
    onLastTimestampChanged: chart.requestPaint()
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
            return height - Math.min(1, value / graph.maximum) * height;
        }

        function drawAverage(context) {
            const segments = [];
            let segment = [];
            let previousTimestamp = 0;
            graph.values.forEach(function (value, index) {
                const timestamp = graph.timestamps[index];
                if (value === null || timestamp <= 0 || timestamp < graph.firstTimestamp
                        || timestamp > graph.lastTimestamp
                        || (previousTimestamp > 0
                            && timestamp - previousTimestamp > graph.maximumGapMilliseconds)) {
                    if (segment.length > 0)
                        segments.push(segment);
                    segment = [];
                }
                if (value !== null && timestamp >= graph.firstTimestamp
                        && timestamp <= graph.lastTimestamp)
                    segment.push({ x: xFor(timestamp), y: yFor(value) });
                previousTimestamp = timestamp;
            });
            if (segment.length > 0)
                segments.push(segment);

            segments.forEach(function (points) {
                if (points.length > 1) {
                    context.beginPath();
                    context.moveTo(points[0].x, height);
                    points.forEach(function (point) { context.lineTo(point.x, point.y); });
                    context.lineTo(points[points.length - 1].x, height);
                    context.closePath();
                    const fill = context.createLinearGradient(0, 0, 0, height);
                    fill.addColorStop(0, Ui.Theme.withAlpha(graph.lineColor, 0.24));
                    fill.addColorStop(1, Ui.Theme.withAlpha(graph.lineColor, 0.01));
                    context.fillStyle = fill;
                    context.fill();
                }
                context.beginPath();
                points.forEach(function (point, index) {
                    if (index === 0)
                        context.moveTo(point.x, point.y);
                    else
                        context.lineTo(point.x, point.y);
                });
                context.strokeStyle = graph.lineColor;
                context.lineWidth = Math.max(1.5, graph.uiScale * 1.5);
                context.lineJoin = "round";
                context.lineCap = "round";
                context.stroke();
                if (points.length === 1) {
                    context.beginPath();
                    context.arc(points[0].x, points[0].y, 2, 0, Math.PI * 2);
                    context.fillStyle = graph.lineColor;
                    context.fill();
                }
            });
        }

        function drawPeaks(context) {
            let drawing = false;
            let previousTimestamp = 0;
            context.beginPath();
            graph.peakValues.forEach(function (value, index) {
                const timestamp = graph.timestamps[index];
                if (value === null || timestamp < graph.firstTimestamp
                        || timestamp > graph.lastTimestamp) {
                    drawing = false;
                    previousTimestamp = 0;
                    return;
                }
                const x = xFor(timestamp);
                const y = yFor(value);
                if (!drawing || (previousTimestamp > 0
                        && timestamp - previousTimestamp > graph.maximumGapMilliseconds))
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
                drawing = true;
                previousTimestamp = timestamp;
            });
            context.setLineDash([3, 3]);
            context.strokeStyle = Ui.Theme.withAlpha(graph.lineColor, 0.58);
            context.lineWidth = 1;
            context.stroke();
            context.setLineDash([]);
        }

        onPaint: {
            const context = getContext("2d");
            context.reset();
            if (graph.values.length === 0)
                return;
            drawAverage(context);
            drawPeaks(context);
        }
    }
}
