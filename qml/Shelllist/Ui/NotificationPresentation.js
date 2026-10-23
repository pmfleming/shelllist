.pragma library

function notificationFor(record) {
    return record && record.notification ? record.notification : (record || ({}));
}

// Presentation only: neither text nor artwork is an action target. A missing
// or repeated app-name summary must not turn a long body/path into a headline.
function previewHeading(record) {
    const n = notificationFor(record);
    const summary = String(n.summary || "").replace(/\s+/g, " ").trim();
    return summary.toLowerCase() === String(n.app_name || "").trim().toLowerCase() ? "" : summary;
}
function previewBody(record) {
    const body = String(notificationFor(record).body || "").replace(/\s+/g, " ").trim();
    return body === previewHeading(record) ? "" : body;
}

// Live snapshots and persisted wrappers share identity, including after close.
function recordKey(record) {
    const n = notificationFor(record);
    return String(n.id) + ":" + String(n.created_unix_ms);
}

// Project an already validated native window. No sorting, date classification,
// request state or mutation belongs here; only newly allocated rows are changed.
function timelineRows(snapshot, requestedDate, collapsed, entries, expandedStacks, loadingMore) {
    const rows = (snapshot.recent || []).map(preview => ({kind: "message", key: recordKey(preview), preview: preview, count: 1, stack: false}));
    for (const date of snapshot.dates || []) {
        if (!date.count) continue;
        rows.push({kind: "date", key: date.key, count: date.count});
        if (date.key !== requestedDate || date.key !== snapshot.date || collapsed) continue;
        appendTimelineEntries(rows, entries, expandedStacks);
        if (loadingMore) rows.push({kind: "more", key: "more"});
    }
    return rows;
}
function appendTimelineEntries(rows, entries, expandedStacks) {
    for (const entry of entries) {
        const expanded = expandedStacks[entry.key] === true;
        rows.push({kind: "message", key: entry.key, preview: entry.preview, count: entry.members.length, stack: entry.members.length > 1, expanded: expanded});
        if (!expanded) continue;
        for (const member of entry.members)
            rows.push({kind: "message", key: "member:" + member.id + ":" + member.created,
                preview: Object.assign({}, entry.preview, {id: member.id, created_unix_ms: member.created}), count: 1, stack: false});
    }
}

function isReplyAction(action) {
    // KDE's inline-reply extension is an exact key, not any app action whose
    // name happens to include "reply" (which must emit ActionInvoked).
    return String(action && action.key || "") === "inline-reply";
}

// Freedesktop reserves "default" for activating the notification itself.
function isDefaultAction(action) {
    return String(action && action.key || "") === "default";
}

// Arrays passed through a Repeater's modelData arrive as array-like sequences.
function notificationActions(notification) {
    const actions = notification && notification.actions;
    return actions && typeof actions.length === "number" && typeof actions !== "string" ? Array.prototype.slice.call(actions) : [];
}

function standardActions(notification) {
    return notificationActions(notification).filter(function (action) {
        return !isReplyAction(action) && !isDefaultAction(action);
    });
}

function defaultAction(notification) {
    return notificationActions(notification).find(isDefaultAction) || null;
}

function urgency(notification) {
    const hints = notification && notification.hints || ({});
    return Number(hints.urgency || 0);
}

function replyAction(notification) {
    return notificationActions(notification).find(isReplyAction) || null;
}

function groupKey(record) {
    const notification = notificationFor(record);
    const hints = notification.hints || ({});
    return String(notification.group_key || hints.desktop_entry || notification.app_name || "unknown");
}

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Compact timestamp: relative within a day, then "Yesterday", then a date.
function timeLabel(createdMs, nowMs) {
    const created = Number(createdMs);
    if (!Number.isFinite(created) || created <= 0)
        return "";
    const minutes = Math.max(0, Math.floor((nowMs - created) / 60000));
    if (minutes < 1)
        return "now";
    if (minutes < 60)
        return minutes + "m";
    const then = new Date(created);
    const today = new Date(nowMs);
    today.setHours(0, 0, 0, 0);
    if (then >= today)
        return Math.floor(minutes / 60) + "h";
    if (then >= new Date(today.getTime() - 86400000))
        return "Yesterday";
    return then.getDate() + " " + monthNames[then.getMonth()];
}
