interface Measurement {
    coverage?: number;
    memory_source?: string;
    disk_space_scope?: string;
    attribution_method?: string;
    sample_interval_ms?: number;
    resources_shared?: boolean;
    [capabilityAvailable: string]: unknown;
}
interface ResourcePoint {
    availability?: Readonly<Record<string, boolean>>;
    coverage?: number;
    sample_count?: number;
    energy_confidence?: string;
    [metric: string]: unknown;
}
interface ApplicationResource {
    running?: boolean;
    measurement?: Measurement;
    energy_source?: string;
    energy_confidence?: string;
    [metric: string]: unknown;
}
interface MetricSummary {
    available?: boolean;
    mean?: number | null;
    peak?: number | null;
    observed_ms?: number;
    coverage?: number;
}
interface HistorySummary {
    window_start_ms?: number;
    window_end_ms?: number;
    weighting?: string;
    metrics?: Readonly<Record<string, MetricSummary>>;
}

function measured(value: unknown): value is number {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

function finite(value: unknown) {
    const number = Number(value);
    return isFinite(number) ? number : 0;
}

function decimal(value: unknown, digits?: number) {
    return finite(value).toFixed(digits === undefined ? 1 : digits);
}

function integer(value: unknown) {
    return Math.round(finite(value)).toLocaleString();
}

function percent(value: unknown) {
    return decimal(value, 1) + "%";
}

function ratioPercent(value: unknown) {
    return decimal(finite(value) * 100, 1) + "%";
}

function bytes(value: unknown) {
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

function rate(value: unknown) {
    return bytes(value) + "/s";
}

function power(value: unknown) {
    if (measured(value) && value > 0 && value < 0.01)
        return "<0.01 W";
    return decimal(value, 2) + " W";
}

function energy(value: unknown) {
    if (measured(value) && value > 0 && value < 0.01)
        return "<0.01 mWh";
    return finite(value) >= 1000 ? decimal(finite(value) / 1000, 2) + " Wh" : decimal(value, 2) + " mWh";
}

function observedTime(milliseconds: unknown) {
    const seconds = Math.max(0, finite(milliseconds)) / 1000;
    return seconds < 60 ? decimal(seconds, 0) + " s" : seconds < 3600
        ? decimal(seconds / 60, 1) + " min" : decimal(seconds / 3600, 1) + " h";
}

function formatted(value: unknown, kind: string) {
    if (!measured(value)) return "Unavailable";
    if (kind === "bytes") return bytes(value);
    if (kind === "rate") return rate(value);
    if (kind === "power") return power(value);
    if (kind === "energy") return energy(value);
    return percent(value);
}

// The canonical daemon summary is duration-weighted over the selected window,
// independent of pagination. Never integrate the latest rate over missing time,
// sum cumulative counters, or reuse a summary from another range.
function windowSummary(summary: HistorySummary | null | undefined, start: number, end: number): HistorySummary | null {
    return summary && summary.weighting === "observed-duration" && start < end
        && summary.window_start_ms === start && summary.window_end_ms === end ? summary : null;
}

function summaryMetric(summary: HistorySummary | null | undefined, metric: string): MetricSummary {
    const stats = summary?.metrics?.[metric];
    const window = finite(summary?.window_end_ms) - finite(summary?.window_start_ms);
    return stats?.available === true && measured(stats.mean) && measured(stats.observed_ms)
        && stats.observed_ms > 0 && stats.observed_ms <= window ? stats : {};
}

function periodEstimate(summary: HistorySummary | null | undefined, metric: string): number | null {
    const stats = summaryMetric(summary, metric);
    if (!stats.available || !metric.endsWith("_bytes_per_second") && metric !== "average_power_watts")
        return null;
    const result = Number(stats.mean) * Number(stats.observed_ms) / (metric === "average_power_watts" ? 3600 : 1000);
    return measured(result) ? result : null;
}

function periodText(summary: HistorySummary | null | undefined, metric: string): string {
    const estimate = periodEstimate(summary, metric);
    return estimate === null ? "Unavailable" : "≈ " + formatted(estimate, metric === "average_power_watts" ? "energy" : "bytes");
}

function observationText(summary: HistorySummary | null | undefined, metric: string): string {
    const stats = summaryMetric(summary, metric);
    if (!stats.available) return "No observed intervals";
    return observedTime(stats.observed_ms) + " observed / "
        + observedTime(finite(summary?.window_end_ms) - finite(summary?.window_start_ms));
}

function compactObservation(summary: HistorySummary | null | undefined, metric: string): string {
    const stats = summaryMetric(summary, metric);
    if (!stats.available) return "—";
    const compact = (ms: number) => observedTime(ms).replace(".0 ", " ").replace(" min", "m").replace(" h", "h").replace(" s", "s");
    return compact(Number(stats.observed_ms)) + "/" + compact(finite(summary?.window_end_ms) - finite(summary?.window_start_ms));
}

interface ResourceInterval { start: number; end: number; value: number; }

// Buckets END at timestamp_ms. Clip their actual duration to the requested
// window; never extrapolate, carry forward over gaps, or render duplicate ends.
// Shared by all chart styles and tested without depending on Canvas internals.
function historySegments(points: readonly ResourcePoint[], metric: string, start: number, end: number): ResourceInterval[][] {
    if (!isFinite(start) || !isFinite(end) || start >= end) return [];
    const segments: ResourceInterval[][] = [];
    let previous: ResourceInterval | null = null;
    let lastTimestamp = -Infinity;
    for (const point of points) {
        const timestamp = point.timestamp_ms;
        const duration = point.duration_ms;
        if (!measured(timestamp) || timestamp <= lastTimestamp) {
            previous = null;
            continue;
        }
        const previousTimestamp = lastTimestamp;
        lastTimestamp = timestamp;
        if (!measured(duration) || duration <= 0 || !historicalMetricAvailable(point, metric)) {
            previous = null;
            continue;
        }
        const left = Math.max(start, timestamp - duration, previousTimestamp);
        const right = Math.min(end, timestamp);
        if (right <= left) continue;
        const interval = {start: left, end: right, value: Number(point[metric])};
        if (previous && left === previous.end)
            segments[segments.length - 1].push(interval);
        else
            segments.push([interval]);
        previous = interval;
    }
    return segments;
}

function missingIntervals(segments: readonly ResourceInterval[][], start: number, end: number): {start: number; end: number}[] {
    const gaps: {start: number; end: number}[] = [];
    let cursor = start;
    for (const segment of segments) {
        for (const interval of segment) {
            if (interval.start > cursor) gaps.push({start: cursor, end: interval.start});
            cursor = Math.max(cursor, interval.end);
        }
    }
    if (cursor < end) gaps.push({start: cursor, end});
    return gaps;
}

function rangeEnergyConfidence(points: readonly ResourcePoint[]): string {
    const confidences = points.filter(point => historicalMetricAvailable(point, "average_power_watts"))
        .map(point => text(point.energy_confidence, "unknown").toLowerCase());
    if (confidences.includes("low")) return "low";
    if (confidences.length === 0 || confidences.some(value => !["high", "medium"].includes(value))) return "unknown";
    return confidences.includes("medium") ? "medium" : "high";
}

function currentValue(resource: ApplicationResource, metric: string): unknown {
    if (metric !== "average_power_watts") return resource[metric];
    // Zero is a reading, not a reason to fall back to another power source.
    return measured(resource.estimated_app_power_watts) ? resource.estimated_app_power_watts : resource.power_watts;
}

function duration(value: unknown) {
    const milliseconds = Math.max(0, finite(value));
    return milliseconds >= 1000 ? decimal(milliseconds / 1000, 1) + " s" : integer(milliseconds) + " ms";
}

function text(value: unknown, fallback?: string) {
    const result = String(value === undefined || value === null ? "" : value).trim();
    return result || fallback || "Unavailable";
}

function metricCapability(metric: string): string {
    if (metric.startsWith("gpu_")) return "gpu";
    if (metric.startsWith("memory_")) return "memory";
    if (metric.startsWith("cpu_") || ["process_count", "thread_count", "major_faults_per_second"].includes(metric)) return "cpu";
    if (metric.startsWith("disk_space_")) return "disk_space";
    if (metric.startsWith("referenced_file_") || metric === "open_file_disk_bytes") return "referenced_files";
    if (metric === "network_connection_count") return "network_connections";
    if (metric.startsWith("network_")) return "network_bytes";
    if (metric.includes("power_watts") || ["energy_mwh", "battery_percent", "attributed_fraction"].includes(metric)) return "energy";
    return "storage";
}

function historicalMetricAvailable(point: ResourcePoint | null | undefined, metric: string): boolean {
    const capability = metricCapability(metric);
    // Legacy-record normalization belongs to app-daemon, not the chart.
    const value = point ? point[metric] : undefined;
    return !!point && measured(value)
        && !!point.availability && point.availability[capability] === true
        && (capability !== "energy" || point.energy_source === "rapl");
}

function currentMetricAvailable(resource: ApplicationResource, metric: string): boolean {
    if (!measured(currentValue(resource, metric))) return false;
    const measurement: Measurement = resource.measurement || ({});
    switch (metricCapability(metric)) {
    case "cpu": return Number(measurement.coverage) > 0;
    case "memory": return ["pss", "rss-fallback"].includes(String(measurement.memory_source));
    case "disk_space": return measurement.disk_space_scope === "identified-app-directories";
    case "energy": return resource.energy_source === "rapl";
    default: return measurement[metricCapability(metric) + "_available"] === true;
    }
}

function currentMetadataBadges(application: ApplicationResource) {
    const measurement: Measurement = application.measurement || ({});
    const badges = [
        { text: text(measurement.attribution_method, "Unknown attribution"), tone: "accent" },
        { text: measured(measurement.coverage) ? ratioPercent(measurement.coverage) + " process coverage" : "Unknown process coverage", tone: !measured(measurement.coverage) || measurement.coverage < 0.8 ? "warning" : "normal" },
        { text: measured(measurement.sample_interval_ms) && measurement.sample_interval_ms > 0 ? duration(measurement.sample_interval_ms) + " sampling interval" : "Unknown sampling interval", tone: "normal" },
        { text: text(measurement.memory_source, "Unknown memory").toUpperCase() + " memory", tone: "normal" },
        { text: application.energy_source === "rapl" ? "Energy estimate · " + text(application.energy_confidence).toLowerCase() + " confidence" : "Energy unavailable", tone: "warning" }
    ];
    if (measurement.resources_shared)
        badges.push({ text: "Shared attribution", tone: "warning" });
    return badges;
}

function historicalMetadataBadges(latestPoint: ResourcePoint) {
    return [
        { text: "Retained history", tone: "accent" },
        { text: ratioPercent(latestPoint.coverage) + " process coverage", tone: Number(latestPoint.coverage) < 0.8 ? "warning" : "normal" },
        { text: integer(latestPoint.sample_count) + " samples", tone: "normal" },
        { text: latestPoint.energy_source === "rapl" ? "Energy estimate · " + text(latestPoint.energy_confidence).toLowerCase() + " confidence" : "Energy unavailable", tone: "warning" }
    ];
}

function metadataBadges(application: ApplicationResource | null | undefined, latestPoint: ResourcePoint | null | undefined) {
    if (application && application.running)
        return currentMetadataBadges(application);
    return latestPoint ? historicalMetadataBadges(latestPoint) : [];
}
