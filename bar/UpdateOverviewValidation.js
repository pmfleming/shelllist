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
    return value.tools.every(tool => !!tool && [tool.name, tool.installed_version, tool.phase, tool.error].every(text)
            && [tool.last_successful_check, tool.last_activation].every(time))
        && value.timers.every(timer => !!timer && text(timer.unit) && time(timer.next_at) && time(timer.last_at))
        && value.issues.every(issue => !!issue && /^[A-Za-z0-9][A-Za-z0-9-]{0,159}$/.test(issue.run_id || "")
            && typeof issue.lane === "string" && typeof issue.component === "string" && typeof issue.error === "string"
            && text(issue.incident) && issue.failed_at !== null && time(issue.failed_at));
}
