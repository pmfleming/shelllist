.pragma library

// Both published and staged windows are bounded independently of catalog size.
var maximumEntries = 200;

// Pure transitions of the controller's one unpublished window. Rejection never
// changes it; requests, bounded restarts and publication remain controller-owned.
function continuationValid(window, page, length) {
    const end = (window.offset || 0) + length;
    if (page.total < end || window.pages >= 128)
        return false;
    if (window.total >= 0 && window.total !== page.total)
        return false;
    if (window.retainThrough >= 0 && window.retainThrough !== (page.retain_through || 0))
        return false;
    return page.cursor
        ? page.entries.length > 0 && page.cursor !== window.cursor && end < page.total
        : end === page.total;
}
function advance(window, page) {
    if (window.revision && window.revision !== page.revision)
        return {error: "revision"};
    if (window.entries.length + page.entries.length > maximumEntries)
        return {error: "limit"};
    const entries = window.entries.concat(page.entries);
    if (new Set(entries.map(entry => entry.job.id)).size !== entries.length)
        return {error: "duplicate"};
    if (!continuationValid(window, page, entries.length))
        return {error: "continuation"};
    return {window: Object.assign({}, window, {
        entries, revision: page.revision, total: page.total,
        retainThrough: page.retain_through || 0, cursor: page.cursor || "",
        diagnostic: page.error || window.diagnostic, pages: window.pages + 1
    })};
}
function needsMore(window) {
    return !window.append && !!window.cursor
        && window.entries.length < Math.min(maximumEntries, Math.max(window.target, window.retainThrough - (window.offset || 0)));
}
