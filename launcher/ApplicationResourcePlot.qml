pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Canvas {
    required property var points
    required property var series
    required property string chartStyle
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    required property real maximum
    property real uiScale: 1
    readonly property bool paired: chartStyle === "paired-columns"
    readonly property var segments: series.map(descriptor => Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds))
    readonly property color guideColor: Ui.Theme.border
    readonly property color missingColor: Ui.Theme.mutedText

    implicitHeight: Math.round(96 * uiScale)
    antialiasing: true
    Accessible.ignored: true // The owner supplies the metric, scale and coverage.

    function xFor(timestamp: real): real {
        return (timestamp - rangeStartMilliseconds) / Math.max(1, rangeEndMilliseconds - rangeStartMilliseconds) * width;
    }
    function baselineY(): real {
        // Paired I/O has independent coverage bands below its positive baseline.
        return height - 3 - (paired ? series.length * 4 * uiScale : 0);
    }
    function yFor(value: real, _index: int): real {
        const fraction = Math.min(1, Math.max(0, value) / Math.max(0.01, maximum));
        return baselineY() - fraction * Math.max(1, baselineY() - 3);
    }
    function hatch(context: var, left: real, right: real, top: real, bandHeight: real): void {
        if (right <= left || bandHeight <= 0) return;
        context.save();
        context.beginPath();
        context.rect(left, top, right - left, bandHeight);
        context.clip();
        context.fillStyle = Ui.Theme.withAlpha(missingColor, 0.08);
        context.fillRect(left, top, right - left, bandHeight);
        context.strokeStyle = Ui.Theme.withAlpha(missingColor, 0.35);
        context.lineWidth = 1;
        context.beginPath();
        for (let x = left - bandHeight; x < right; x += 6 * uiScale) {
            context.moveTo(x, top + bandHeight);
            context.lineTo(x + bandHeight, top);
        }
        context.stroke();
        context.restore();
    }
    function drawGaps(context: var, index: int): void {
        const bandHeight = paired ? 4 * uiScale : height;
        const top = paired ? height - (series.length - index) * bandHeight : 0;
        Resources.missingIntervals(segments[index], rangeStartMilliseconds, rangeEndMilliseconds).forEach(gap => {
            hatch(context, xFor(gap.start), xFor(gap.end), top, bandHeight);
        });
    }
    function strokeSegment(context: var, segment: var, index: int): void {
        const first = segment[0];
        const vertices = [{x: xFor(first.start), y: yFor(first.value, index)}];
        for (const interval of segment) {
            vertices.push({x: xFor(interval.start), y: yFor(interval.value, index)});
            vertices.push({x: xFor(interval.end), y: yFor(interval.value, index)});
        }
        context.strokeStyle = series[index].color;
        context.lineWidth = 2.2 * uiScale;
        // Retained bucket steps, not smoothing or exact allocation event times.
        Ui.ChartDrawing.segment(context, vertices, baselineY(), Ui.Theme.withAlpha(series[index].color, 0.16), false);
    }
    function columnRect(interval: var, index: int): var {
        const left = xFor(interval.start);
        const right = xFor(interval.end);
        const slot = (right - left) / (paired ? series.length : 1);
        const gutter = Math.min(3 * uiScale, slot / 4);
        const y = yFor(interval.value, index);
        // Width follows observed duration; never extend into missing time.
        return {x: left + (paired ? index * slot : 0) + gutter / 2,
            y: y, width: Math.max(0, slot - gutter), height: Math.max(0, baselineY() - y)};
    }
    function drawColumns(context: var, index: int): void {
        context.fillStyle = series[index].color;
        segments[index].forEach(segment => segment.forEach(interval => {
            const rect = columnRect(interval, index);
            context.fillRect(rect.x, rect.y, rect.width, rect.height);
        }));
    }
    onSegmentsChanged: requestPaint()
    onMaximumChanged: requestPaint()
    onChartStyleChanged: requestPaint()
    onUiScaleChanged: requestPaint()
    onGuideColorChanged: requestPaint()
    onMissingColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.reset();
        context.clearRect(0, 0, width, height);
        context.strokeStyle = Ui.Theme.withAlpha(guideColor, 0.65);
        context.lineWidth = 1;
        context.beginPath();
        [0, 0.5, 1].forEach(fraction => {
            const y = 3 + (baselineY() - 3) * fraction;
            context.moveTo(0, y);
            context.lineTo(width, y);
        });
        context.stroke();
        series.forEach((_descriptor, index) => {
            drawGaps(context, index);
            if (chartStyle === "steps") segments[index].forEach(segment => strokeSegment(context, segment, index));
            else drawColumns(context, index);
        });
    }
}
