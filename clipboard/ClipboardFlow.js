.pragma library

function operationRunning(operation) {
    return operation && ["started", "progress"].includes(operation.status);
}

function rememberTerminal(operation, handled, limit) {
    if (!operation || !operation.id || operationRunning(operation))
        return { duplicate: false, handled: handled };
    if (handled[operation.id])
        return { duplicate: true, handled: handled };
    const next = Object.assign({}, handled);
    next[operation.id] = true;
    const ids = Object.keys(next);
    if (ids.length > limit)
        delete next[ids[0]];
    return { duplicate: false, handled: next };
}

function detailedEntry(selected, details, replacedSourceIds) {
    const entry = details ? details.entry : null;
    if (!selected || !entry)
        return selected;
    const matches = entry.id === selected.id || replacedSourceIds.includes(selected.id);
    if (!matches)
        return selected;
    return entry.id !== selected.id || entry.revision >= selected.revision ? entry : selected;
}
