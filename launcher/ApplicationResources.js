.pragma library

"use strict";
function finite(value) {
    const number = Number(value);
    return isFinite(number) ? number : 0;
}
function decimal(value, digits) {
    return finite(value).toFixed(digits === undefined ? 1 : digits);
}
function integer(value) {
    return Math.round(finite(value)).toLocaleString();
}
function percent(value) {
    return decimal(value, 1) + "%";
}
function ratioPercent(value) {
    return decimal(finite(value) * 100, 1) + "%";
}
function bytes(value) {
    const amount = Math.max(0, finite(value));
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let scaled = amount;
    let unit = 0;
    while (scaled >= 1024 && unit < units.length - 1) {
        scaled /= 1024;
        unit += 1;
    }
    const digits = unit === 0 ? 0 : scaled >= 100 ? 0 : 1;
    return scaled.toFixed(digits) + " " + units[unit];
}
function rate(value) {
    return bytes(value) + "/s";
}
function power(value) {
    return decimal(value, 2) + " W";
}
function duration(value) {
    const milliseconds = Math.max(0, finite(value));
    return milliseconds >= 1000 ? decimal(milliseconds / 1000, 1) + " s" : integer(milliseconds) + " ms";
}
function text(value, fallback) {
    const result = String(value === undefined || value === null ? "" : value).trim();
    return result || fallback || "Unavailable";
}
function metricCapability(metric) {
    if (metric.startsWith("gpu_"))
        return "gpu";
    if (metric.startsWith("memory_"))
        return "memory";
    if (metric.startsWith("cpu_") || ["process_count", "thread_count", "major_faults_per_second"].includes(metric))
        return "cpu";
    if (metric.startsWith("disk_space_"))
        return "disk_space";
    if (metric.startsWith("referenced_file_") || metric === "open_file_disk_bytes")
        return "referenced_files";
    if (metric === "network_connection_count")
        return "network_connections";
    if (metric.startsWith("network_"))
        return "network_bytes";
    if (metric.includes("power_watts") || ["energy_mwh", "battery_percent", "attributed_fraction"].includes(metric))
        return "energy";
    return "storage";
}
function historicalMetricAvailable(point, metric) {
    const capability = metricCapability(metric);
    // Legacy-record normalization belongs to app-daemon, not the chart.
    const value = point ? point[metric] : undefined;
    return !!point && typeof value === "number" && isFinite(value)
        && !!point.availability && point.availability[capability] === true;
}
function currentMetricAvailable(resource, metric) {
    const measurement = resource.measurement || ({});
    switch (metricCapability(metric)) {
        case "cpu": return Number(measurement.coverage) > 0;
        case "memory": return ["pss", "rss-fallback"].includes(String(measurement.memory_source));
        case "disk_space": return measurement.disk_space_scope === "identified-app-directories";
        case "energy": return resource.energy_source === "rapl";
        default: return measurement[metricCapability(metric) + "_available"] === true;
    }
}
function currentMetadataBadges(application) {
    const measurement = application.measurement || ({});
    const badges = [
        { text: text(measurement.attribution_method, "Unknown attribution"), tone: "accent" },
        { text: ratioPercent(measurement.coverage) + " coverage", tone: Number(measurement.coverage) < 0.8 ? "warning" : "normal" },
        { text: duration(measurement.sample_interval_ms) + " samples", tone: "normal" },
        { text: text(measurement.memory_source, "Unknown memory").toUpperCase() + " memory", tone: "normal" },
        { text: "Energy " + text(application.energy_confidence).toLowerCase(), tone: application.energy_confidence === "low" ? "warning" : "normal" }
    ];
    if (measurement.resources_shared)
        badges.push({ text: "Shared attribution", tone: "warning" });
    return badges;
}
function historicalMetadataBadges(latestPoint) {
    return [
        { text: "Retained history", tone: "accent" },
        { text: ratioPercent(latestPoint.coverage) + " coverage", tone: Number(latestPoint.coverage) < 0.8 ? "warning" : "normal" },
        { text: integer(latestPoint.sample_count) + " samples", tone: "normal" },
        { text: "Energy " + text(latestPoint.energy_confidence).toLowerCase(), tone: latestPoint.energy_confidence === "low" ? "warning" : "normal" }
    ];
}
function metadataBadges(application, latestPoint) {
    if (application && application.running)
        return currentMetadataBadges(application);
    return latestPoint ? historicalMetadataBadges(latestPoint) : [];
}
