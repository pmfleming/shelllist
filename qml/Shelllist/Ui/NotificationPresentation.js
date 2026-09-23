.pragma library

function notificationFor(record) {
    return record && record.notification ? record.notification : (record || ({}));
}

function isReplyAction(action) {
    return String(action && action.key || "").toLowerCase().indexOf("reply") >= 0;
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

function groupRecords(records) {
    const groups = [];
    const byKey = Object.create(null);
    (records || []).forEach(function (record) {
        const key = groupKey(record);
        let group = byKey[key];
        if (!group) {
            const notification = notificationFor(record);
            group = {
                key: key,
                appName: notification.app_name || "Notifications",
                desktopEntry: (notification.hints || ({})).desktop_entry || "",
                records: []
            };
            byKey[key] = group;
            groups.push(group);
        }
        group.records.push(record);
    });
    return groups;
}

function newestFirst(records) {
    return (records || []).slice().sort(function (left, right) {
        return Number(notificationFor(right).created_unix_ms || 0) - Number(notificationFor(left).created_unix_ms || 0) || Number(notificationFor(right).id || 0) - Number(notificationFor(left).id || 0);
    });
}

// Keep expired/dismissed records in the agenda, without duplicating records
// also present in the active snapshot. IDs alone can be reused after restart.
function recentRecords(active, history) {
    const activeKeys = Object.create(null);
    (active || []).forEach(function (record) {
        const n = notificationFor(record);
        activeKeys[n.id + ":" + n.created_unix_ms] = true;
    });
    return newestFirst((active || []).concat((history || []).filter(function (record) {
        const n = notificationFor(record);
        return !activeKeys[n.id + ":" + n.created_unix_ms];
    })));
}

function previewCapacity(height, spacing, margin) {
    // Header, DND row, view-all row and their gaps; each preview is 48px.
    return Math.max(0, Math.floor((height - margin * 2 - 28 - 34 - 34 - spacing * 2) / (48 + spacing)));
}

function mergeHistory(existing, incoming) {
    const byId = Object.create(null);
    (existing || []).concat(incoming || []).forEach(function (record) {
        byId[record.history_id] = record;
    });
    return Object.keys(byId).map(function (id) {
        return byId[id];
    }).sort(function (left, right) {
        return Number(right.history_id) - Number(left.history_id);
    });
}

// Reconcile QML ListModels without resetting existing delegates and their focus.
function syncKeyedModel(model, rows) {
    for (let i = 0; i < rows.length; ++i) {
        // Store JSON as a scalar role: ListModel otherwise converts nested action
        // arrays into QQmlListModels, breaking Array.isArray/filter in delegates.
        const row = {
            key: rows[i].key,
            payload: JSON.stringify(rows[i].payload)
        };
        let found = -1;
        for (let j = i; j < model.count; ++j) {
            if (model.get(j).key === row.key) {
                found = j;
                break;
            }
        }
        if (found < 0)
            model.insert(i, row);
        else {
            if (found !== i)
                model.move(found, i, 1);
            if (model.get(i).payload !== row.payload)
                model.setProperty(i, "payload", row.payload);
        }
    }
    if (model.count > rows.length)
        model.remove(rows.length, model.count - rows.length);
}

function filterRecords(records, query) {
    const needle = String(query || "").trim().toLowerCase();
    return (records || []).filter(function (record) {
        const n = notificationFor(record);
        return [n.app_name, n.summary, n.body].join(" ").toLowerCase().indexOf(needle) >= 0;
    });
}

function relativeTime(createdMs, nowMs) {
    const created = Number(createdMs);
    if (!Number.isFinite(created) || created <= 0)
        return "";
    const minutes = Math.max(0, Math.floor((nowMs - created) / 60000));
    if (minutes < 1)
        return "now";
    if (minutes < 60)
        return minutes + "m ago";
    if (minutes < 1440)
        return Math.floor(minutes / 60) + "h ago";
    return Math.floor(minutes / 1440) + "d ago";
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

function notificationMonitor(notification, focusedMonitor, monitorNames) {
    const available = monitorNames || [];
    const source = String(notification && notification.source_monitor || "");
    if (source.length > 0 && available.indexOf(source) >= 0)
        return source;
    if (focusedMonitor && available.indexOf(focusedMonitor) >= 0)
        return focusedMonitor;
    return available.length > 0 ? available[0] : "";
}

function dndLabel(notifications, nowMs) {
    if (!notifications || !notifications.dnd)
        return "DND off";
    const until = Number(notifications.dnd_until_unix_ms || 0);
    if (until <= 0)
        return "DND on";
    const minutes = Math.max(1, Math.ceil((until - nowMs) / 60000));
    return minutes >= 60 ? "DND " + Math.ceil(minutes / 60) + "h" : "DND " + minutes + "m";
}
