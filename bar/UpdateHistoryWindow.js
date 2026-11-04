.pragma library

// Both published and staged windows are bounded independently of catalog size.
var maximumEntries = 200;

function anchorIds(selectedId, entries) {
    return [...new Set([selectedId, entries.length ? entries[entries.length - 1].job.id : ""].filter(Boolean))];
}

// Capture one unpublished read from the accepted window. Arrays are immutable:
// advance() concatenates; neither construction nor rejection changes the source.
function begin(current, request) {
    const retain = !request.recent && current.key === request.key && !request.exact;
    const advancing = request.append && current.entries.length >= maximumEntries;
    const retained = retain ? current : {offset: 0, startCursor: ""};
    const position = advancing ? {offset: current.offset + current.entries.length, startCursor: current.cursor} : retained;
    const continuation = request.append || position.offset > 0;
    return {
        key: request.key, append: request.append, offset: position.offset, startCursor: position.startCursor,
        anchors: continuation ? current.anchors : retain ? anchorIds(request.selectedId, current.entries) : [],
        replace: request.recent || advancing, entries: request.append && !advancing ? current.entries : [],
        revision: continuation ? current.revision : "", total: continuation ? current.total : -1,
        retainThrough: -1, target: retain && !advancing ? current.entries.length : 0,
        pages: 0, retried: false, diagnostic: "", notice: "", cursor: request.append ? current.cursor : position.startCursor
    };
}

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
