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

function shortVersion(value) {
    if (!value) return qsTr("Unknown");
    const match = /^\/nix\/store\/[a-z0-9]+-nixos-system-(.+)$/.exec(value);
    return match ? match[1] : value;
}

function componentGroups(run) {
    if (!run) return [];
    const parts = run.components.map((part, index) => Object.assign({}, part, {componentIndex: index, runId: run.job.id}));
    return [
        {key: "failed", title: qsTr("Failed"), parts: parts.filter(part => !!part.error)},
        {key: "changed", title: qsTr("Changed"), parts: parts.filter(part => part.changed && !part.error)},
        {key: "unchanged", title: qsTr("Unchanged"), parts: parts.filter(part => !part.changed && !part.error)}
    ].filter(group => group.parts.length > 0);
}

function componentCount(run) {
    if (!run) return "";
    const changed = run.components.filter(part => part.changed).length;
    return (run.lane === "ai-tools" || run.lane === "ai-tools-stale"
        ? qsTr("%1 of %2 tools changed") : qsTr("%1 of %2 components changed")).arg(changed).arg(run.components.length);
}

function componentSummary(part) {
    return [part.name + " · " + label(part.phase) + " · " + (part.changed ? qsTr("Changed") : qsTr("Unchanged")),
        qsTr("Before: %1").arg(part.before || qsTr("Unknown")), qsTr("After: %1").arg(part.after || qsTr("Unknown")),
        part.error ? qsTr("Error: %1").arg(part.error) : ""].filter(Boolean).join("\n");
}

function absoluteTime(seconds) {
    return validTime(seconds) ? new Date(seconds * 1000).toISOString() : qsTr("Not recorded");
}

function runSummary(run, nowMs) {
    return [run.title, qsTr("Run: %1").arg(run.job.id),
        qsTr("Lane: %1").arg(label(run.lane)), qsTr("Operation: %1").arg(label(run.job.operation)),
        qsTr("Status / outcome: %1 / %2").arg(label(run.job.status)).arg(label(run.outcome)),
        qsTr("Phase: %1").arg(label(run.job.phase)), qsTr("Started: %1").arg(absoluteTime(run.job.started_at)),
        isRunning(run) ? qsTr("Still running") : qsTr("Finished: %1").arg(absoluteTime(run.job.finished_at)),
        qsTr("Duration: %1").arg(durationLabel(run, nowMs)), qsTr("Exit code: %1").arg(exitLabel(run.job.exit_code)),
        run.job.error ? qsTr("Error: %1").arg(run.job.error) : "",
        run.components.length ? "\n" + componentCount(run) : "",
        ...run.components.map(part => "\n" + componentSummary(part))].filter(Boolean).join("\n");
}

function logSource(run) {
    return run && run.job.operation === "manual-rebuild" ? qsTr("Rebuild log file") : qsTr("Worker journal");
}

function logTone(line) {
    return /\berror:/i.test(line) ? "error" : /\bwarning:/i.test(line) ? "warning" : "info";
}

function ageLabel(seconds, nowMs) {
    if (!validTime(seconds) || seconds * 1000 > nowMs) return qsTr("Age unknown");
    const minutes = Math.floor((nowMs - seconds * 1000) / 60000);
    return minutes >= 1440 ? qsTr("%1 d").arg(Math.floor(minutes / 1440))
        : minutes >= 60 ? qsTr("%1 h").arg(Math.floor(minutes / 60)) : qsTr("%1 min").arg(minutes);
}

function deferredCandidate(state) {
    // The current snapshot's error describes a failed readiness read. Its
    // placeholder ready=false lane must not masquerade as a known absence.
    return state && state.available && !state.error && Array.isArray(state.lanes) ? state.lanes.find(lane => lane.name === "delayed") || null : null;
}

function laneOverview(state, name, nowMs) {
    const job = state && state.available && Array.isArray(state.jobs) ? state.jobs.find(job => job.name === name) : null;
    const candidate = name === "system" ? deferredCandidate(state) : null;
    let status = qsTr("Not reported");
    if (!state || !state.available) status = qsTr("Unavailable");
    else if (job && job.status === "running") status = qsTr("Running · %1").arg(label(job.phase));
    else if (job && (job.status === "failed" || job.status === "interrupted")) status = label(job.status);
    else if (job && ["blocked", "stale", "queued"].includes(job.phase)) status = label(job.phase);
    else if (candidate && candidate.ready) status = qsTr("Ready · deferred candidate");
    // A terminal staging job is not proof that this system is still staged or unbooted.
    else if (job && job.phase === "staged") status = qsTr("Idle · last run staged for boot");
    else if (job && job.status === "completed") status = qsTr("Idle · last result: %1").arg(label(job.phase));
    const stamp = job ? job.finished_at || job.started_at : null;
    const timing = job ? (job.status === "running" ? qsTr("Started %1") : qsTr("Last worker run %1")).arg(timeLabel(stamp, nowMs)) : qsTr("Last check not reported");
    return {name: name, title: label(name), status: status, timing: timing,
        operation: job ? label(job.operation) : "", error: job && job.error ? job.error : ""};
}

function nowSummary(state, nowMs) {
    return ["system", "ai-tools", "ai-tools-stale"].map(name => {
        const lane = laneOverview(state, name, nowMs);
        return lane.title + ": " + lane.status;
    }).join(" · ");
}

function rowSubtitle(run, nowMs) {
    // Keep the useful change count ahead of metadata when narrow rows elide.
    return [changeSummary(run), timeLabel(run.job.started_at, nowMs), label(run.lane), label(run.outcome)].filter(Boolean).join(" · ");
}
