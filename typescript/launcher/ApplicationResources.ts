interface ResourcePoint {
    metric_availability?: Readonly<Record<string, boolean>>;
    [metric: string]: unknown;
}
interface ApplicationResource {
    metric_availability?: Readonly<Record<string, boolean>>;
    [metric: string]: unknown;
}
interface MetricSummary {
    observed_total?: number | null;
    total_unit?: string | null;
    available?: boolean;
    mean?: number | null;
    peak?: number | null;
    observed_ms?: number;
    coverage?: number;
}
interface HistorySummary {
    energy_confidence?: string;
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
    return stats.available && ["bytes", "mWh"].includes(String(stats.total_unit)) && measured(stats.observed_total)
        ? stats.observed_total : null;
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

function rangeEnergyConfidence(summary: HistorySummary | null | undefined): string {
    return ["low", "medium", "high"].includes(String(summary?.energy_confidence)) ? String(summary?.energy_confidence) : "unknown";
}

function currentValue(resource: ApplicationResource, metric: string): unknown {
    if (metric !== "average_power_watts") return resource[metric];
    // Zero is a reading, not a reason to fall back to another power source.
    return measured(resource.estimated_app_power_watts) ? resource.estimated_app_power_watts : resource.power_watts;
}

function text(value: unknown, fallback?: string) {
    const result = String(value === undefined || value === null ? "" : value).trim();
    return result || fallback || "Unavailable";
}

function historicalMetricAvailable(point: ResourcePoint | null | undefined, metric: string): boolean {
    return !!point && point.metric_availability?.[metric] === true && measured(point[metric]);
}

function currentMetricAvailable(resource: ApplicationResource, metric: string): boolean {
    return resource.metric_availability?.[metric] === true && measured(currentValue(resource, metric));
}
