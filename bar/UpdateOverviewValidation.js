.pragma library

function valid(value) {
    const text = value => value === null || typeof value === "string";
    const time = value => value === null || (Number.isSafeInteger(value) && value > 0 && value < 253402300800);
    const flag = value => value === null || typeof value === "boolean";
    const strings = (value, limit) => Array.isArray(value) && value.length <= limit && value.every(item => typeof item === "string");
    if (!value || value.schema_version !== 1 || typeof value.available !== "boolean" || !time(value.observed_at)
            || !text(value.error) || !text(value.history_error) || !text(value.timers_error) || typeof value.history_available !== "boolean"
            || !Array.isArray(value.issues) || value.issues.length > 50 || !Number.isSafeInteger(value.issue_total) || value.issue_total < value.issues.length
            || !Array.isArray(value.tools) || value.tools.length > 32 || !Array.isArray(value.timers) || value.timers.length > 64) return false;
    if (value.available && (!value.system || !value.baseline || value.observed_at === null)) return false;
    const system = value.system;
    if (system !== null && (!system || ![system.active, system.booted, system.profile].every(text)
            || ![system.staged_for_next_boot, system.pending_transaction, system.queued].every(flag)
            || ![system.staged_since, system.last_successful_check].every(time) || !strings(system.errors, 4))) return false;
    const baseline = value.baseline;
    if (baseline !== null && (!baseline || !flag(baseline.valid) || !time(baseline.approved_at)
            || !text(baseline.revision) || !text(baseline.error) || !strings(baseline.reasons, 33))) return false;
    const git = value.git;
    if (git !== undefined && git !== null) {
        if (!git || typeof git.available !== "boolean" || !text(git.path) || !text(git.error)) return false;
        if (git.available && (![git.revision, git.branch, git.upstream].every(text)
                || ![git.observed_at, git.target_observed_at].every(time) || git.observed_at === null
                || typeof git.dirty !== "boolean" || typeof git.shallow !== "boolean"
                || ![git.ahead, git.behind].every(n => n === null || (Number.isSafeInteger(n) && n >= 0 && n <= 4294967295)))) return false;
    }
    const apps = value.applications;
    if (apps !== undefined && apps !== null) {
        const field = (s, max) => typeof s === "string" && s.length > 0 && s.length <= max && !/[\x00-\x1f\x7f-\x9f]/.test(s);
        const release = r => r === undefined || r === null || (!!r
            && field(r.source, 512) && r.source.startsWith("https://")
            && (r.version === null || field(r.version, 80))
            && time(r.checked_at) && time(r.attempted_at)
            && (r.version === null) === (r.checked_at === null)
            && (r.checked_at === null || r.attempted_at !== null)
            && typeof r.stale === "boolean"
            && (r.error === null || (typeof r.error === "string" && r.error.length <= 512))
            && (r.stale || (r.version !== null && r.error === null)));
        if (!apps || typeof apps.available !== "boolean" || !text(apps.error)
                || !time(apps.observed_at) || !text(apps.active_system)
                || !Array.isArray(apps.packages) || apps.packages.length > 512
                || !Number.isSafeInteger(apps.total) || apps.total < apps.packages.length || apps.total > 4096
                || (apps.available && (apps.observed_at === null || !field(apps.active_system, 512)))
                || (!apps.available && (apps.total !== 0 || apps.packages.length !== 0))
                || !apps.packages.every(p => !!p && field(p.name, 160) && field(p.scope, 80)
                    && (p.version === null || field(p.version, 80)) && release(p.release))) return false;
    }
    const freshness = f => f === undefined || f === null || (!!f
        && [f.latest_version, f.source, f.published_at, f.origin, f.hold_reason].every(text)
        && [f.stale, f.held].every(flag) && time(f.hold_since)
        && (f.comparison === null || ["current", "newer", "ahead", "rebuild"].includes(f.comparison)));
    return value.tools.every(tool => !!tool && [tool.name, tool.installed_version, tool.phase, tool.error].every(text)
            && [tool.last_successful_check, tool.last_activation].every(time) && freshness(tool.freshness))
        && value.timers.every(timer => !!timer && text(timer.unit) && time(timer.next_at) && time(timer.last_at))
        && value.issues.every(issue => !!issue && /^[A-Za-z0-9][A-Za-z0-9-]{0,159}$/.test(issue.run_id || "")
            && typeof issue.lane === "string" && typeof issue.component === "string" && typeof issue.error === "string"
            && text(issue.incident) && issue.failed_at !== null && time(issue.failed_at));
}
