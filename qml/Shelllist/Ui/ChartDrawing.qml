pragma Singleton
import QtQuick

QtObject {
    function dashed(context: var, x0: real, y0: real, x1: real, y1: real, dash: real, gap: real): void {
        context.beginPath();
        context.moveTo(x0, y0);
        context.lineTo(x1, y1);
        context.setLineDash([dash, gap]);
        context.stroke();
        context.setLineDash([]);
    }

    function segment(context: var, points: var, baseline: real, fill: var, isolatedDots: bool): void {
        if (points.length === 0)
            return;
        const originalFill = context.fillStyle;
        if (points.length > 1) {
            context.beginPath();
            context.moveTo(points[0].x, baseline);
            for (const point of points)
                context.lineTo(point.x, point.y);
            context.lineTo(points[points.length - 1].x, baseline);
            context.closePath();
            context.fillStyle = fill;
            context.fill();
        }
        context.fillStyle = originalFill;
        context.beginPath();
        if (points.length === 1 && isolatedDots) {
            context.arc(points[0].x, points[0].y, 2, 0, Math.PI * 2);
            context.fill();
            return;
        }
        context.moveTo(points[0].x, points[0].y);
        for (let index = 1; index < points.length; ++index)
            context.lineTo(points[index].x, points[index].y);
        context.stroke();
    }

    // Callers own axes, availability/continuity, and stroke styling. Each
    // segment is independent so missing measurements are never bridged.
    function series(context: var, segments: var, baseline: real, fill: var, isolatedDots: bool): void {
        for (const points of segments)
            segment(context, points, baseline, fill, isolatedDots);
    }
}
