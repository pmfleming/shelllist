.pragma library

function estimate(seconds, emptyText) {
    const value = Math.max(0, Number(seconds) || 0);
    if (value <= 0)
        return emptyText || "estimating";
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return hours > 0 ? hours + "h " + minutes + "m" : Math.max(1, minutes) + "m";
}
