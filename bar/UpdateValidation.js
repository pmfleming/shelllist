.pragma library

// Wire validation only. Request ownership and atomic publication stay in UpdateController.
function text(value) { return typeof value === "string"; }
function flag(value) { return typeof value === "boolean"; }
function nullable(value, check) { return value === null || check(value); }
function optional(value, check) { return value === undefined || nullable(value, check); }
function integer(value, min, max) { return Number.isSafeInteger(value) && value >= min && value <= max; }
function list(value, limit, check) { return Array.isArray(value) && value.length <= limit && value.every(check); }
function runId(value) { return /^[A-Za-z0-9][A-Za-z0-9-]{0,159}$/.test(value); }
function field(value, max) { return text(value) && value.length > 0 && value.length <= max && !/[\x00-\x1f\x7f-\x9f]/.test(value); }
function version(value) { return field(value, 80); }
function optionalText(value) { return nullable(value, text); }
function optionalFlag(value) { return nullable(value, flag); }
// Overview timestamps exclude zero and are calendar-bounded; history permits epoch zero.
function observedTime(value) { return nullable(value, n => integer(n, 1, 253402300799)); }
function historyTime(value) { return integer(value, 0, Number.MAX_SAFE_INTEGER); }
function count(value) { return nullable(value, n => integer(n, 0, 4294967295)); }

function system(value) {
    return value === null || (!!value && [value.active, value.booted, value.profile].every(optionalText)
        && [value.staged_for_next_boot, value.pending_transaction, value.queued].every(optionalFlag)
        && [value.staged_since, value.last_successful_check].every(observedTime) && list(value.errors, 4, text));
}
function baseline(value) {
    return value === null || (!!value && optionalFlag(value.valid) && observedTime(value.approved_at)
        && [value.revision, value.error].every(optionalText) && list(value.reasons, 33, text));
}
function git(value) {
    return !!value && flag(value.available) && [value.path, value.error].every(optionalText)
        && (!value.available || ([value.revision, value.branch, value.upstream].every(optionalText)
            && [value.observed_at, value.target_observed_at].every(observedTime) && value.observed_at !== null
            && [value.dirty, value.shallow].every(flag) && [value.ahead, value.behind].every(count)));
}
function release(value) {
    return !!value && field(value.source, 512) && value.source.startsWith("https://")
        && nullable(value.version, version) && [value.checked_at, value.attempted_at].every(observedTime)
        && (value.version === null) === (value.checked_at === null)
        && (value.checked_at === null || value.attempted_at !== null) && flag(value.stale)
        && nullable(value.error, error => text(error) && error.length <= 512)
        && (value.stale || (value.version !== null && value.error === null));
}
function application(value) {
    return !!value && field(value.name, 160) && field(value.scope, 80)
        && nullable(value.version, version) && optional(value.release, release);
}
function applications(value) {
    return !!value && flag(value.available) && [value.error, value.active_system].every(optionalText)
        && observedTime(value.observed_at) && list(value.packages, 512, application)
        && integer(value.total, value.packages.length, 4096)
        && (value.available ? value.observed_at !== null && field(value.active_system, 512)
            : value.total === 0 && value.packages.length === 0);
}
function freshness(value) {
    return !!value && [value.latest_version, value.source, value.published_at, value.origin, value.hold_reason].every(optionalText)
        && [value.stale, value.held].every(optionalFlag) && observedTime(value.hold_since)
        && nullable(value.comparison, comparison => ["current", "newer", "ahead", "rebuild"].includes(comparison));
}
function tool(value) {
    return !!value && [value.name, value.installed_version, value.phase, value.error].every(optionalText)
        && [value.last_successful_check, value.last_activation].every(observedTime) && optional(value.freshness, freshness);
}
function timer(value) { return !!value && optionalText(value.unit) && [value.next_at, value.last_at].every(observedTime); }
function overviewIssue(value) {
    return !!value && runId(value.run_id || "") && [value.lane, value.component, value.error].every(text)
        && optionalText(value.incident) && value.failed_at !== null && observedTime(value.failed_at);
}
function overview(value) {
    return !!value && value.schema_version === 1 && [value.available, value.history_available].every(flag)
        && observedTime(value.observed_at) && [value.error, value.history_error, value.timers_error].every(optionalText)
        && list(value.issues, 50, overviewIssue) && integer(value.issue_total, value.issues.length, Number.MAX_SAFE_INTEGER)
        && (!value.available || (!!value.system && !!value.baseline && value.observed_at !== null))
        && system(value.system) && baseline(value.baseline) && optional(value.git, git) && optional(value.applications, applications)
        && list(value.tools, 32, tool) && list(value.timers, 64, timer);
}
function incident(value) { return text(value) && value.trim().length > 0 && value.length <= 2048 && !/[\u0000-\u001f\u007f]/.test(value); }
function component(value) {
    return !!value && [value.name, value.phase].every(text) && flag(value.changed)
        && [value.before, value.after, value.error].every(optionalText) && optional(value.incident, incident);
}
function historyIssue(value, componentCount) {
    return !!value && nullable(value.component, n => integer(n, 0, componentCount - 1)) && historyTime(value.failed_at)
        && nullable(value.recovered_at, n => historyTime(n) && n > value.failed_at)
        && nullable(value.recovered_run_id, runId) && (value.recovered_at === null) === (value.recovered_run_id === null);
}
function entry(value) {
    if (!value || !value.job || !list(value.components, 32, component)) return false;
    const job = value.job;
    return value.schema_version === 1 && text(value.lane) && runId(job.id || "")
        && [value.title, value.outcome, job.operation, job.phase, job.status].every(text)
        && historyTime(job.started_at) && nullable(job.finished_at, historyTime) && nullable(job.exit_code, Number.isSafeInteger)
        && optionalText(job.error) && optional(value.failed_stage, text) && optional(value.deployed, flag)
        && (value.issues === undefined || list(value.issues, 33, issue => historyIssue(issue, value.components.length)));
}
function historyPage(value) {
    return !!value && list(value.entries, 100, entry) && flag(value.available) && [value.revision, value.coverage].every(text)
        && [value.cursor, value.error].every(optionalText) && integer(value.total, value.entries.length, 4096)
        && (value.retain_through === undefined || integer(value.retain_through, 0, value.total));
}
