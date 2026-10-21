.pragma library

// Display-only projections. Never infer activation from readiness or an old phase.
function label(value) {
    const labels = {
        system: qsTr("System"), "ai-tools": qsTr("AI tools"), "ai-tools-stale": qsTr("AI tools stale check"),
        "check-delayed": qsTr("Check deferred system update"), "run-delayed": qsTr("Run deferred system update"),
        "catch-up-delayed": qsTr("Catch up deferred system update"), "apply-delayed": qsTr("Apply deferred system update"),
        "approve-current": qsTr("Approve current baseline"), "check-runtime": qsTr("Check running system"),
        "manual-rebuild": qsTr("Manual system rebuild"), "ai-update": qsTr("Update AI tools"), "ai-stale": qsTr("Check AI tool freshness"),
        starting: qsTr("Starting"), checking: qsTr("Checking"), building: qsTr("Building"), verifying: qsTr("Verifying"),
        staging: qsTr("Staging for next boot"), staged: qsTr("Staged for next boot"), recovering: qsTr("Recovering"),
        approved: qsTr("Baseline approved"), blocked: qsTr("Blocked"), queued: qsTr("Queued"), ready: qsTr("Ready to apply"),
        current: qsTr("No changes"), "no-change": qsTr("No changes"), activated: qsTr("Activated"), available: qsTr("Update available"),
        skipped: qsTr("Skipped"), stale: qsTr("Stale"), running: qsTr("Running"), completed: qsTr("Completed"),
        interrupted: qsTr("Interrupted"), failed: qsTr("Failed"), partial: qsTr("Partial"),
        "never-checked": qsTr("Never checked"), held: qsTr("On hold")
    };
    if (Object.prototype.hasOwnProperty.call(labels, value)) return labels[value];
    const words = String(value || "").replace(/[-_]+/g, " ");
    return words ? words.charAt(0).toUpperCase() + words.slice(1) : qsTr("Unknown");
}

function outcomeIcon(outcome) {
    const icons = {activated: "check", staged: "inventory_2", ready: "play_arrow", running: "autorenew",
        queued: "schedule", current: "checklist", "no-change": "checklist", blocked: "block",
        failed: "error", partial: "warning", interrupted: "cancel", available: "download",
        skipped: "skip_next", approved: "shield", completed: "done_all"};
    return Object.prototype.hasOwnProperty.call(icons, outcome) ? icons[outcome] : "history";
}

function changeSummary(run) {
    const changed = run.components.filter(part => part.changed).length;
    const failed = run.components.filter(part => !!part.error).length;
    const parts = [];
    if (changed) {
        const tools = run.lane === "ai-tools" || run.lane === "ai-tools-stale";
        parts.push(tools ? (changed === 1 ? qsTr("1 tool changed") : qsTr("%1 tools changed").arg(changed))
            : (changed === 1 ? qsTr("1 component changed") : qsTr("%1 components changed").arg(changed)));
    }
    if (failed) parts.push(qsTr("%1 failed").arg(failed));
    if (!parts.length && run.job.error) return qsTr("Run error; no component changes recorded");
    if (!parts.length && run.components.length) return qsTr("No component changes");
    return parts.join(" / ");
}

function validTime(seconds) {
    return typeof seconds === "number" && seconds > 0 && Number.isFinite(new Date(seconds * 1000).getTime());
}

function timeLabel(seconds, nowMs) {
    if (!validTime(seconds)) return qsTr("Not recorded");
    const date = new Date(seconds * 1000);
    const today = new Date(nowMs);
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const clock = Qt.formatDateTime(date, "HH:mm");
    if (date >= today && date < tomorrow) return qsTr("Today %1").arg(clock);
    if (date >= yesterday && date < today) return qsTr("Yesterday %1").arg(clock);
    return Qt.formatDateTime(date, date.getFullYear() === today.getFullYear() ? "d MMM HH:mm" : "d MMM yyyy HH:mm");
}

// Match notifications' local calendar periods, without adding selectable rows.
function dateGroup(seconds, nowMs) {
    if (!validTime(seconds)) return qsTr("Unknown date");
    const date = new Date(seconds * 1000);
    const today = new Date(nowMs);
    today.setHours(0, 0, 0, 0);
    const week = new Date(today);
    week.setDate(week.getDate() - (week.getDay() + 6) % 7);
    const month = new Date(today.getFullYear(), today.getMonth(), 1);
    if (date >= today) return qsTr("Today");
    if (date >= week) return qsTr("This week");
    if (date >= month) return qsTr("This month");
    return qsTr("Older");
}

function isRunning(run) {
    // Abandoned jobs can retain status=running; the catalog's reconciled outcome wins.
    return run.outcome === "running" && run.job.status === "running";
}

function durationLabel(run, nowMs) {
    const start = run.job.started_at;
    const end = isRunning(run) ? Math.floor(nowMs / 1000) : run.job.finished_at;
    if (!validTime(start) || !validTime(end) || end < start) return qsTr("Unknown duration");
    const seconds = Math.floor(end - start);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds % 3600 / 60);
    const text = hours ? qsTr("%1 h %2 min %3 s").arg(hours).arg(minutes).arg(seconds % 60)
        : minutes ? qsTr("%1 min %2 s").arg(minutes).arg(seconds % 60) : qsTr("%1 s").arg(seconds);
    return isRunning(run) ? qsTr("%1 elapsed").arg(text) : text;
}

function exitLabel(code) {
    if (code === null) return qsTr("Not recorded");
    const meanings = {0: qsTr("success"), 1: qsTr("failed"), 130: qsTr("cancelled")};
    return Object.prototype.hasOwnProperty.call(meanings, code) ? qsTr("%1 (%2)").arg(code).arg(meanings[code]) : String(code);
}

function rowSubtitle(run, nowMs) {
    // Keep the useful change count ahead of metadata when narrow rows elide.
    return [changeSummary(run), timeLabel(run.job.started_at, nowMs), label(run.lane), label(run.outcome)].filter(Boolean).join(" · ");
}
