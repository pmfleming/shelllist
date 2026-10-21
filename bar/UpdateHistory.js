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
function project(entries, collapse, expandedIds, selectedId) {
    const rows = [];
    for (let index = 0; index < entries.length;) {
        const first = entries[index];
        let end = index + 1;
        if (collapse && routine(first)) {
            while (end < entries.length && routine(entries[end]) && entries[end].lane === first.lane
                    && entries[end].job.operation === first.job.operation && day(entries[end].job.started_at) === day(first.job.started_at)) ++end;
        }
        if (end - index < 2) {
            rows.push({run: first});
        } else {
            const runs = entries.slice(index, end);
            const ids = runs.map(run => run.job.id);
            const oldGroup = selectedId.startsWith("_quiet-") ? selectedId.slice(7) : "";
            const anchor = ids.includes(oldGroup) ? oldGroup : expandedIds.find(id => ids.includes(id)) || ids[0];
            const expanded = expandedIds.some(id => ids.includes(id)) || ids.includes(selectedId);
            rows.push({quietGroup: {id: "_quiet-" + anchor, ids: ids, first: first, last: runs[runs.length - 1], expanded: expanded}});
            if (expanded) runs.forEach(run => rows.push({run: run}));
        }
        index = end;
    }
    return rows;
}
