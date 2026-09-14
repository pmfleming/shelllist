.pragma library

function nonnegative(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

function observedPoint(point) {
    return nonnegative(point.active_time_ms) && nonnegative(point.timestamp_ms) && point.timestamp_ms > 0;
}

function activeTimeline(samples) {
    const timed = samples.filter(observedPoint);
    const first = timed.reduce(function (value, point) {
        return Math.min(value, point.active_time_ms);
    }, Infinity);
    const last = timed.reduce(function (value, point) {
        return Math.max(value, point.active_time_ms);
    }, 0);
    return {
        first: first,
        duration: timed.length ? last - first : 0,
        available: timed.length > 0
    };
}

function metricAvailable(point, metric, positiveOnly) {
    const value = point[metric];
    if (!observedPoint(point) || !nonnegative(value))
        return false;
    if (positiveOnly && value <= 0)
        return false;
    if (metric === "percentage" && value > 100)
        return false;
    return metric !== "time_to_full_seconds" || (point.charging === true && value > 0);
}

function continuousAfter(previous, point) {
    return previous !== null && point.continuous === true && point.active_time_ms > previous.active_time_ms && point.timestamp_ms > previous.timestamp_ms;
}

// Use observed active time, not wall-clock gaps, to place samples on the chart.
function series(points, metric, minimumMaximum, positiveOnly) {
    const samples = Array.isArray(points) ? points : [];
    const timeline = activeTimeline(samples);
    let maximum = Math.max(1, minimumMaximum || 0);
    const segments = [];
    let segment = null, previous = null;
    samples.forEach(function (point) {
        if (!metricAvailable(point, metric, positiveOnly)) {
            segment = null;
            previous = null;
            return;
        }
        if (!segment || !continuousAfter(previous, point)) {
            segment = [];
            segments.push(segment);
        }
        segment.push({
            x: timeline.duration > 0 ? (point.active_time_ms - timeline.first) / timeline.duration : 0.5,
            value: point[metric],
            timestamp_ms: point.timestamp_ms
        });
        maximum = Math.max(maximum, point[metric]);
        previous = point;
    });
    return {
        segments: segments,
        maximum: maximum,
        activeDurationMs: timeline.duration,
        hasActiveTimeline: timeline.available
    };
}

function nearestSample(points, x) {
    let nearest = null;
    let distance = Infinity;
    points.forEach(function (segment) {
        segment.forEach(function (point) {
            if (Math.abs(point.x - x) < distance) {
                distance = Math.abs(point.x - x);
                nearest = point;
            }
        });
    });
    return nearest;
}

function activeDuration(points) {
    const samples = (points || []).filter(function (point) {
        return nonnegative(point.active_time_ms);
    });
    if (samples.length === 0)
        return "Collecting active-time samples";
    const duration = Math.max(0, samples[samples.length - 1].active_time_ms - samples[0].active_time_ms);
    const minutes = Math.floor(duration / 60000);
    const hours = Math.floor(minutes / 60);
    const label = hours > 0 ? hours + "h " + minutes % 60 + "m" : (minutes > 0 ? minutes + "m" : "<1m");
    return label + " observed · sleep/offline time omitted";
}
