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
    readonly property bool paired: chartStyle === "columns" || chartStyle === "paired-area"
    readonly property var segments: series.map(descriptor => Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds))
    readonly property color guideColor: Ui.Theme.border
    readonly property color missingColor: Ui.Theme.mutedText

    implicitHeight: Math.round(48 * uiScale)
    antialiasing: true
    Accessible.ignored: true // The owning row supplies complete static summaries.

    function xFor(timestamp: real): real {
        return (timestamp - rangeStartMilliseconds) / Math.max(1, rangeEndMilliseconds - rangeStartMilliseconds) * width;
    }
    function baselineY(): real {
        // Overlay coverage bands sit BELOW the data baseline, so a missing GPU
        // interval cannot hatch over a valid zero CPU/RAM trace.
        return paired ? height / 2 : height - 3 - (series.length > 1 ? series.length * 4 * uiScale : 0);
    }
    function yFor(value: real, index: int): real {
        const fraction = Math.min(1, Math.max(0, value) / maximum);
        if (paired)
            return baselineY() - Number(series[index].direction) * fraction * (height / 2 - 3);
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
        // Opposite-direction plots shade each half independently. Overlaid
        // traces use separate thin coverage bands; one missing series must not
        // obscure another valid series or imply that both were observed.
        const bandHeight = paired ? height / 2 : series.length === 1 ? height : 4 * uiScale;
        const top = paired ? (Number(series[index].direction) > 0 ? 0 : height / 2)
            : series.length === 1 ? 0 : height - (series.length - index) * bandHeight;
        Resources.missingIntervals(segments[index], rangeStartMilliseconds, rangeEndMilliseconds).forEach(gap => {
            hatch(context, xFor(gap.start), xFor(gap.end), top, bandHeight);
        });
    }
    function strokeSegment(context: var, segment: var, index: int): void {
        const descriptor = series[index];
        const first = segment[0];
        const area = chartStyle === "area" || chartStyle === "paired-area";
        // The first bucket starts with its own reading; join endpoints only
        // inside this observed segment. Steps retain each bucket's width.
        const vertices = [{x: xFor(first.start), y: yFor(first.value, index)}];
        for (const interval of segment) {
            const y = yFor(interval.value, index);
            if (chartStyle === "steps")
                vertices.push({x: xFor(interval.start), y: y});
            vertices.push({x: xFor(interval.end), y: y});
        }
        context.strokeStyle = descriptor.color;
        context.lineWidth = 1.6 * uiScale;
        context.setLineDash(descriptor.dashed ? [4 * uiScale, 3 * uiScale] : []);
        Ui.ChartDrawing.segment(context, vertices, baselineY(), area ? Ui.Theme.withAlpha(descriptor.color, 0.18) : null, false);
        context.setLineDash([]);
    }
    function drawColumns(context: var, index: int): void {
        context.fillStyle = series[index].color;
        segments[index].forEach(segment => segment.forEach(interval => {
            const left = xFor(interval.start);
            const right = xFor(interval.end);
            const y = yFor(interval.value, index);
            const gutter = Math.min(2 * uiScale, (right - left) / 5);
            // Never expand a narrow bucket into a neighbouring missing region.
            context.fillRect(left + gutter / 2, Math.min(y, baselineY()), Math.max(0, right - left - gutter), Math.max(0.7, Math.abs(y - baselineY())));
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
        context.strokeStyle = Ui.Theme.withAlpha(guideColor, 0.45);
        context.lineWidth = 1;
        context.beginPath();
        [0.25, 0.5, 0.75].forEach(fraction => {
            context.moveTo(width * fraction, 0);
            context.lineTo(width * fraction, height);
        });
        context.moveTo(0, baselineY());
        context.lineTo(width, baselineY());
        context.stroke();
        series.forEach((_descriptor, index) => {
            drawGaps(context, index);
            if (chartStyle === "columns") drawColumns(context, index);
            else segments[index].forEach(segment => strokeSegment(context, segment, index));
        });
    }
}
