.pragma library

function notificationFor(record) {
    return record && record.notification ? record.notification : (record || ({}));
}

function groupKey(record) {
    const notification = notificationFor(record);
    const hints = notification.hints || ({});
    return String(notification.group_key || hints.desktop_entry
        || notification.app_name || "unknown");
}

function groupRecords(records) {
    const groups = [];
    const byKey = {};
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
