import QtQuick
import Shelllist.Ui as Ui

Ui.ChartFrame {
    id: graph

    required property var points
    property string metric: "percentage"
    property real minimumMaximum: 0
    property bool positiveOnly: false
    property double maximumGapMilliseconds: 30 * 60 * 1000

    readonly property var values: (points || []).map(function (point) {
        const raw = point[metric];
        if (raw === null || raw === undefined)
            return null;
        const value = Number(raw);
        if (!isFinite(value) || (positiveOnly && value <= 0))
            return null;
        return Math.max(0, value);
    })
    readonly property var timestamps: (points || []).map(function (point) {
        const value = Number(point.timestamp_ms || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })
    readonly property double firstTimestamp: timestamps.reduce(function (current, value) {
        return value > 0 ? Math.min(current, value) : current;
    }, Number.MAX_VALUE)
    readonly property double lastTimestamp: timestamps.reduce(function (current, value) {
        return Math.max(current, value);
    }, 0)
    readonly property real maximum: Math.max(minimumMaximum, 1,
        values.reduce(function (current, value) {
            return value === null ? current : Math.max(current, value);
        }, 0))

    onValuesChanged: chart.requestPaint()
    onTimestampsChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onRepaintRequested: chart.requestPaint()

    Canvas {
        id: chart
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const values = graph.values;
            if (values.length === 0)
                return;
            const first = graph.firstTimestamp === Number.MAX_VALUE
                ? 0 : graph.firstTimestamp;
            const span = Math.max(1, graph.lastTimestamp - first);
            let drawing = false;
            let previousTimestamp = 0;
            let validCount = 0;
            let onlyX = 0;
            let onlyY = 0;
            context.beginPath();
            values.forEach(function (value, index) {
                const timestamp = graph.timestamps[index];
                if (value === null || timestamp <= 0) {
                    drawing = false;
                    previousTimestamp = 0;
                    return;
                }
                const x = (timestamp - first) / span * width;
                const y = height - Math.min(1, value / graph.maximum) * height;
                if (!drawing || (previousTimestamp > 0
                        && timestamp - previousTimestamp > graph.maximumGapMilliseconds))
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
                drawing = true;
                previousTimestamp = timestamp;
                validCount += 1;
                onlyX = x;
                onlyY = y;
            });
            context.strokeStyle = graph.lineColor;
            context.lineWidth = 1.5;
            context.lineJoin = "round";
            context.lineCap = "round";
            context.stroke();
            if (validCount === 1) {
                context.beginPath();
                context.arc(onlyX, onlyY, 2, 0, Math.PI * 2);
                context.fillStyle = graph.lineColor;
                context.fill();
            }
        }
    }
}
