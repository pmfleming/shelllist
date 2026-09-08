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

function discharging(point) {
    return point.mode === "discharging" || (!point.mode && point.charging === false && point.plugged === false);
}

function energyInterval(previous, point) {
    if (!previous || !observedPoint(previous) || !observedPoint(point))
        return false;
    return continuousAfter(previous, point) && discharging(previous) && discharging(point) && nonnegative(previous.power_watts) && nonnegative(point.power_watts);
}

function accumulateEnergy(buckets, previous, point, timeline, intervalMs) {
    const start = previous.active_time_ms - timeline.first;
    const end = point.active_time_ms - timeline.first;
    const powerChange = point.power_watts - previous.power_watts;
    for (let offset = start; offset < end; ) {
        const index = Math.floor(offset / intervalMs);
        const stop = Math.min(end, (index + 1) * intervalMs);
        const startPower = previous.power_watts + powerChange * (offset - start) / (end - start);
        const endPower = previous.power_watts + powerChange * (stop - start) / (end - start);
        const bucket = buckets[index] || {
            x0: index * intervalMs / timeline.duration,
            x1: Math.min(timeline.duration, (index + 1) * intervalMs) / timeline.duration,
            value: 0,
            observedMs: 0
        };
        bucket.value += (startPower + endPower) / 2 * (stop - offset) / 3600000;
        bucket.observedMs += stop - offset;
        buckets[index] = bucket;
        offset = stop;
    }
}

// Integrate discharge only; never bridge sleep, restarts, or charging transitions.
function energySeries(points) {
    const samples = Array.isArray(points) ? points : [];
    const timeline = activeTimeline(samples);
    const intervalMs = Math.max(900000, Math.ceil(timeline.duration / 48 / 900000) * 900000);
    const buckets = {};
    samples.forEach(function (point, index) {
        const previous = samples[index - 1];
        if (energyInterval(previous, point))
            accumulateEnergy(buckets, previous, point, timeline, intervalMs);
    });
    const bars = Object.keys(buckets).map(function (key) {
        return buckets[key];
    });
    return {
        bars: bars,
        maximum: Math.max(0.1, ...bars.map(function (bar) {
            return bar.value;
        })),
        totalWh: bars.reduce(function (total, bar) {
            return total + bar.value;
        }, 0),
        intervalMs: intervalMs,
        activeDurationMs: timeline.duration
    };
}

function chargeLimit(protection) {
    return protection.enabled === true && !protection.charge_once_active && nonnegative(protection.end_percent) && protection.end_percent > 0 && protection.end_percent < 100 ? protection.end_percent : null;
}

function validCharge(battery, target) {
    return battery.available === true && battery.charging === true && nonnegative(battery.percentage) && battery.percentage < target;
}

function remainingChargeSeconds(battery, target) {
    const seconds = battery.time_to_full_seconds;
    if (!validCharge(battery, target) || !nonnegative(seconds) || seconds <= 0 || seconds > 86400)
        return 0;
    // This capped-target ETA remains an approximation of the full-charge estimate.
    return seconds * (target - battery.percentage) / (100 - battery.percentage);
}

function chargeForecast(battery) {
    battery = battery || {};
    const limit = chargeLimit(battery.protection || {});
    const target = limit === null ? 100 : limit;
    const seconds = remainingChargeSeconds(battery, target);
    return {
        limit: limit,
        target: target,
        percentage: battery.percentage,
        seconds: seconds,
        estimating: validCharge(battery, target) && seconds === 0
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
