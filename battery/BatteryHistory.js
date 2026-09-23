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
    if (metric === "power_watts" && (point.power_valid === false || (point.power_valid !== true && value === 0)))
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
    const breaks = [];
    let segment = null, previous = null;
    samples.forEach(function (point) {
        if (!metricAvailable(point, metric, positiveOnly)) {
            segment = null;
            previous = null;
            return;
        }
        const sample = {
            x: timeline.duration > 0 ? (point.active_time_ms - timeline.first) / timeline.duration : 0.5,
            value: point[metric],
            timestamp_ms: point.timestamp_ms,
            charging: point.charging === true
        };
        if (!segment || !continuousAfter(previous, point)) {
            if (previous !== null)
                breaks.push({ from: segment[segment.length - 1], to: sample });
            segment = [];
            segments.push(segment);
        }
        segment.push(sample);
        maximum = Math.max(maximum, point[metric]);
        previous = point;
    });
    return {
        segments: segments,
        breaks: breaks,
        maximum: maximum,
        activeDurationMs: timeline.duration,
        hasActiveTimeline: timeline.available
    };
}

// Interpolate signed power through zero at charge/discharge transitions, then
// draw both directions above the baseline. Never bridge missing data or suspend.
function powerAreas(segments) {
    const areas = [];
    segments.forEach(function (segment) {
        if (!segment.length)
            return;
        let area = { charging: segment[0].charging, points: [segment[0]] };
        areas.push(area);
        for (let index = 1; index < segment.length; ++index) {
            const previous = segment[index - 1];
            const point = segment[index];
            if (point.charging !== previous.charging) {
                const total = previous.value + point.value;
                const fraction = total > 0 ? previous.value / total : 0.5;
                const zero = { x: previous.x + (point.x - previous.x) * fraction, value: 0 };
                area.points.push(zero);
                area = { charging: point.charging, points: [zero] };
                areas.push(area);
            }
            area.points.push(point);
        }
    });
    return areas;
}

// Range controls select observed time, matching the daemon's gap-free x axis.
function windowPoints(points, hours, currentPoint) {
    const samples = (points || []).filter(observedPoint);
    // A lightweight daemon observation extends the chart between stored bins.
    // Never append an older event to a newer history response or join a clock reset.
    const last = samples.length ? samples[samples.length - 1] : null;
    if (currentPoint && observedPoint(currentPoint) && (!last || currentPoint.timestamp_ms > last.timestamp_ms))
        samples.push(currentPoint);
    const timeline = activeTimeline(samples);
    const cutoff = timeline.first + timeline.duration - hours * 3600000;
    return samples.filter(function (point) { return point.active_time_ms >= cutoff; });
}
function forecastLabel(battery) {
    const forecast = battery.forecast || {};
    if (!battery.available)
        return "Unavailable";
    if (forecast.seconds > 0)
        return forecast.target === 0 ? "to empty" : (forecast.limit !== null && forecast.limit !== undefined ? "to " + forecast.target + "% limit" : "to full");
    if (forecast.estimating)
        return "Estimating…";
    if (forecast.status === "limit-reached")
        return "Charge limit reached";
    if (forecast.status === "full" || battery.state === "fully-charged")
        return "Fully charged";
    return battery.charging ? "Charging" : (battery.plugged ? "Not charging" : "On battery");
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
