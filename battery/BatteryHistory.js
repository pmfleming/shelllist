.pragma library

// Paint/inspection helpers only. Rust supplies observed-time windows, metric
// validity and discontinuous chart segments in battery.history's chart field.
function nonnegative(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
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
