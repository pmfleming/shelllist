.pragma library

function nonnegative(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

// Wall-clock timestamps are labels only. The daemon has already removed
// unobserved time and explicitly marks where interpolation is unsafe.
function series(points, metric, minimumMaximum, positiveOnly) {
    const samples = Array.isArray(points) ? points : [];
    const timed = samples.filter(function (point) {
        return nonnegative(point.active_time_ms)
            && nonnegative(point.timestamp_ms) && point.timestamp_ms > 0;
    });
    const first = timed.reduce(function (value, point) {
        return Math.min(value, point.active_time_ms);
    }, Infinity);
    const last = timed.reduce(function (value, point) {
        return Math.max(value, point.active_time_ms);
    }, 0);
    const duration = timed.length > 0 ? last - first : 0;
    let maximum = Math.max(1, minimumMaximum || 0);
    const segments = [];
    let segment = null;
    let previous = null;
    samples.forEach(function (point) {
        const value = point[metric];
        const valid = nonnegative(point.active_time_ms)
            && nonnegative(point.timestamp_ms) && point.timestamp_ms > 0
            && nonnegative(value) && (!positiveOnly || value > 0)
            && (metric !== "percentage" || value <= 100)
            && (metric !== "time_to_full_seconds" || (point.charging === true && value > 0));
        if (!valid) {
            segment = null;
            previous = null;
            return;
        }
        if (!segment || point.continuous !== true
                || point.active_time_ms <= previous.active_time_ms
                || point.timestamp_ms <= previous.timestamp_ms) {
            segment = [];
            segments.push(segment);
        }
        segment.push({
            x: duration > 0 ? (point.active_time_ms - first) / duration : 0.5,
            value: value,
            timestamp_ms: point.timestamp_ms
        });
        maximum = Math.max(maximum, value);
        previous = point;
    });
    return { segments: segments, maximum: maximum, activeDurationMs: duration,
        hasActiveTimeline: timed.length > 0 };
}

function activeDuration(points) {
    const samples = (points || []).filter(function (point) {
        return nonnegative(point.active_time_ms);
    });
    if (samples.length === 0)
        return "Collecting active-time samples";
    const duration = Math.max(0, samples[samples.length - 1].active_time_ms
        - samples[0].active_time_ms);
    const minutes = Math.floor(duration / 60000);
    const hours = Math.floor(minutes / 60);
    const label = hours > 0 ? hours + "h " + minutes % 60 + "m"
        : (minutes > 0 ? minutes + "m" : "<1m");
    return label + " observed · sleep/offline time omitted";
}
