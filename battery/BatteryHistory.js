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

// Integrate sampled discharge power over observed time only. Never count
// charging power as consumption, or bridge sleep/restart/mode transitions.
// Fixed active-time buckets keep bar heights comparable (Wh per interval).
function energySeries(points) {
    const samples = Array.isArray(points) ? points : [];
    const timeline = series(samples, "percentage", 100, false);
    const timed = samples.filter(function (point) {
        return nonnegative(point.active_time_ms) && nonnegative(point.timestamp_ms)
            && point.timestamp_ms > 0;
    });
    const first = timed.reduce(function (value, point) {
        return Math.min(value, point.active_time_ms);
    }, Infinity);
    const duration = timeline.activeDurationMs;
    const intervalMs = Math.max(900000, Math.ceil(duration / 48 / 900000) * 900000);
    const buckets = {};
    function discharging(point) {
        return point.mode === "discharging"
            || (!point.mode && point.charging === false && point.plugged === false);
    }
    samples.forEach(function (point, index) {
        const previous = samples[index - 1];
        if (!previous || point.continuous !== true || !discharging(point)
                || !discharging(previous) || !nonnegative(point.power_watts)
                || !nonnegative(previous.power_watts)
                || !nonnegative(previous.active_time_ms) || !nonnegative(point.active_time_ms)
                || !nonnegative(previous.timestamp_ms) || previous.timestamp_ms <= 0
                || !nonnegative(point.timestamp_ms) || point.timestamp_ms <= previous.timestamp_ms
                || point.active_time_ms <= previous.active_time_ms)
            return;
        const start = previous.active_time_ms - first;
        const end = point.active_time_ms - first;
        for (let offset = start; offset < end;) {
            const bucketIndex = Math.floor(offset / intervalMs);
            const stop = Math.min(end, (bucketIndex + 1) * intervalMs);
            const startPower = previous.power_watts + (point.power_watts - previous.power_watts)
                * (offset - start) / (end - start);
            const endPower = previous.power_watts + (point.power_watts - previous.power_watts)
                * (stop - start) / (end - start);
            const bucket = buckets[bucketIndex] || {
                x0: bucketIndex * intervalMs / duration,
                x1: Math.min(duration, (bucketIndex + 1) * intervalMs) / duration,
                value: 0, observedMs: 0
            };
            bucket.value += (startPower + endPower) / 2 * (stop - offset) / 3600000;
            bucket.observedMs += stop - offset;
            buckets[bucketIndex] = bucket;
            offset = stop;
        }
    });
    const bars = Object.keys(buckets).map(function (key) { return buckets[key]; });
    return { bars: bars, maximum: Math.max(0.1, ...bars.map(function (bar) { return bar.value; })),
        totalWh: bars.reduce(function (total, bar) { return total + bar.value; }, 0),
        intervalMs: intervalMs, activeDurationMs: duration };
}

function chargeForecast(battery) {
    battery = battery || {};
    const protection = battery.protection || {};
    const limit = protection.enabled === true && !protection.charge_once_active
        && nonnegative(protection.end_percent) && protection.end_percent > 0
        && protection.end_percent < 100 ? protection.end_percent : null;
    const target = limit === null ? 100 : limit;
    const percentage = battery.percentage;
    const validCharge = battery.available === true && battery.charging === true
        && nonnegative(percentage) && percentage < target;
    const fullSeconds = battery.time_to_full_seconds;
    // Refuse obviously unstable estimates rather than stretching the entire
    // history around them. A capped-target ETA is an explicitly approximate
    // fraction of the daemon's full-charge estimate (not a charging model).
    const seconds = validCharge && nonnegative(fullSeconds) && fullSeconds > 0
        && fullSeconds <= 86400 ? fullSeconds * (target - percentage) / (100 - percentage) : 0;
    return { limit: limit, target: target, percentage: percentage,
        seconds: seconds, estimating: validCharge && seconds === 0 };
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
    const duration = Math.max(0, samples[samples.length - 1].active_time_ms
        - samples[0].active_time_ms);
    const minutes = Math.floor(duration / 60000);
    const hours = Math.floor(minutes / 60);
    const label = hours > 0 ? hours + "h " + minutes % 60 + "m"
        : (minutes > 0 ? minutes + "m" : "<1m");
    return label + " observed · sleep/offline time omitted";
}
