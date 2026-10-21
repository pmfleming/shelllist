.pragma library

function routine(run) {
    return run.outcome === "current" && run.job.status === "completed" && run.job.exit_code === 0
        && run.job.operation !== "manual-rebuild" && !run.job.error && !(run.issues || []).length
        && run.components.every(part => !part.changed && !part.error && !part.incident && ["current", "activated"].includes(part.phase));
}
function day(seconds) {
    const date = new Date(seconds * 1000);
    return [date.getFullYear(), date.getMonth(), date.getDate()].join("-");
}
function routineEnd(entries, index) {
    const first = entries[index];
    const date = day(first.job.started_at);
    let end = index + 1;
    while (end < entries.length && routine(entries[end]) && entries[end].lane === first.lane
            && entries[end].job.operation === first.job.operation && day(entries[end].job.started_at) === date) ++end;
    return end;
}
function quietGroup(runs, expandedIds, selectedId) {
    const ids = runs.map(run => run.job.id);
    const members = new Set(ids);
    // IDs are validated, nonempty strings. Keep remembered-anchor priority,
    // rather than choosing whichever matching run appears first in this page.
    const remembered = expandedIds.find(id => members.has(id));
    const oldGroup = selectedId.startsWith("_quiet-") ? selectedId.slice(7) : "";
    const anchor = members.has(oldGroup) ? oldGroup : remembered || ids[0];
    return {id: "_quiet-" + anchor, ids: ids, first: runs[0], last: runs[runs.length - 1],
        expanded: remembered !== undefined || members.has(selectedId)};
}
function project(entries, collapse, expandedIds, selectedId) {
    const rows = [];
    for (let index = 0; index < entries.length;) {
        const first = entries[index];
        const end = collapse && routine(first) ? routineEnd(entries, index) : index + 1;
        if (end - index < 2) {
            rows.push({run: first});
            index = end;
            continue;
        }
        const runs = entries.slice(index, end);
        const group = quietGroup(runs, expandedIds, selectedId);
        rows.push({quietGroup: group});
        if (group.expanded) runs.forEach(run => rows.push({run: run}));
        index = end;
    }
    return rows;
}
