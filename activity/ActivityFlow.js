.pragma library

function dateKey(value) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, "0");
    const day = String(value.getDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
}

function startOfDay(value) {
    return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}

function eventOverlapsDate(event, value) {
    if (event.all_day && event.start_date) {
        const end = event.end_date || event.start_date;
        return event.start_date <= dateKey(value) && end > dateKey(value);
    }
    const start = startOfDay(value).getTime();
    const end = start + 24 * 60 * 60 * 1000;
    return Number(event.end_unix_ms) > start && Number(event.start_unix_ms) < end;
}

function todoVisible(todo, selectedKey, todayKey) {
    if (todo.due_date)
        return todo.due_date === selectedKey;
    if (todo.due_unix_ms !== null && todo.due_unix_ms !== undefined)
        return dateKey(new Date(todo.due_unix_ms)) === selectedKey;
    return selectedKey === todayKey && !todo.completed;
}

function eventKind(event, streams) {
    if (event.event === "lagged")
        return "lagged";
    if (!["subscribed", "changed"].includes(event.event))
        return "";
    if (event.stream === streams.activity)
        return "activity";
    if (event.stream === streams.notifications)
        return "notifications";
    return event.stream === streams.notificationActive ? "notificationActive" : "";
}
