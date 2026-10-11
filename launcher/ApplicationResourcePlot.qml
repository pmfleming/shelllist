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
    readonly property color gapColor: Ui.Theme.withAlpha(Ui.Theme.text, 0.035)
    // Shade only gaps in all series. One unavailable series must not obscure
    // another series' valid observations, including measured zero.
    readonly property var missingRanges: unobservedRanges()

    implicitHeight: Math.round(96 * uiScale)
    antialiasing: true
    Accessible.ignored: true // The owner supplies the metric, scale and coverage.

    function unobservedRanges(): var {
        const gaps = [];
        const intervals = [];
        segments.forEach(metric => metric.forEach(segment => segment.forEach(interval => intervals.push(interval))));
        intervals.sort((left, right) => left.start - right.start);
        let cursor = rangeStartMilliseconds;
        for (const interval of intervals) {
            if (interval.start > cursor) gaps.push({start: cursor, end: interval.start});
            cursor = Math.max(cursor, interval.end);
        }
        if (cursor < rangeEndMilliseconds) gaps.push({start: cursor, end: rangeEndMilliseconds});
        return gaps;
    }
    function xFor(timestamp: real): real {
        return (timestamp - rangeStartMilliseconds) / Math.max(1, rangeEndMilliseconds - rangeStartMilliseconds) * width;
    }
    function baselineY(): real {
        return height - 3;
    }
    function yFor(value: real, _index: int): real {
        const fraction = Math.min(1, Math.max(0, value) / Math.max(0.01, maximum));
        return baselineY() - fraction * Math.max(1, baselineY() - 3);
    }
    function strokeSegment(context: var, segment: var, index: int): void {
        const first = segment[0];
        const vertices = [{x: xFor(first.start), y: yFor(first.value, index)}];
        for (const interval of segment) {
            if (chartStyle === "steps") vertices.push({x: xFor(interval.start), y: yFor(interval.value, index)});
            vertices.push({x: xFor(interval.end), y: yFor(interval.value, index)});
        }
        context.strokeStyle = series[index].color;
        context.lineWidth = 1.6 * uiScale;
        context.setLineDash(index > 0 ? [4 * uiScale, 3 * uiScale] : []);
        // Memory retains bucket steps; activity joins observations only inside
        // a contiguous segment. Never smooth or connect across missing time.
        const fill = chartStyle === "steps" && index === 0 ? Ui.Theme.withAlpha(series[index].color, 0.08) : null;
        Ui.ChartDrawing.segment(context, vertices, baselineY(), fill, false);
        context.setLineDash([]);
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
            // A measured zero gets a baseline mark; missing intervals get none.
            context.fillRect(rect.x, rect.height === 0 ? rect.y - 1 : rect.y, rect.width, Math.max(1, rect.height));
        }));
    }
    onSegmentsChanged: requestPaint()
    onMaximumChanged: requestPaint()
    onChartStyleChanged: requestPaint()
    onUiScaleChanged: requestPaint()
    onGuideColorChanged: requestPaint()
    onGapColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.reset();
        context.clearRect(0, 0, width, height);
        context.fillStyle = gapColor;
        missingRanges.forEach(gap => context.fillRect(xFor(gap.start), 3, xFor(gap.end) - xFor(gap.start), Math.max(0, baselineY() - 3)));
        context.strokeStyle = Ui.Theme.withAlpha(guideColor, 0.65);
        context.lineWidth = 1;
        Ui.ChartDrawing.dashed(context, 0, 3, width, 3, 2, 4);
        context.beginPath();
        context.moveTo(0, baselineY());
        context.lineTo(width, baselineY());
        context.stroke();
        series.forEach((_descriptor, index) => {
            if (chartStyle === "steps" || chartStyle === "lines") segments[index].forEach(segment => strokeSegment(context, segment, index));
            else drawColumns(context, index);
        });
    }
}
