.pragma library

function monitorBox(monitor) {
    const rotated = Number(monitor.transform || 0) % 2 !== 0;
    return {
        x: monitor.x,
        y: monitor.y,
        width: Math.round((rotated ? monitor.height : monitor.width) / monitor.scale),
        height: Math.round((rotated ? monitor.width : monitor.height) / monitor.scale)
    };
}

function edgeDistance(direction, from, to) {
    if (direction === "l")
        return from.x - to.x - to.width;
    if (direction === "r")
        return from.x + from.width - to.x;
    if (direction === "u" || direction === "t")
        return from.y - to.y - to.height;
    return from.y + from.height - to.y;
}

function edgeOverlap(direction, from, to) {
    if (direction === "l" || direction === "r")
        return Math.max(0, Math.min(from.y + from.height, to.y + to.height) - Math.max(from.y, to.y));
    return Math.max(0, Math.min(from.x + from.width, to.x + to.width) - Math.max(from.x, to.x));
}

function directionalMonitor(direction, monitors) {
    const focused = monitors.find(function (monitor) {
        return monitor.focused;
    });
    if (!focused)
        return null;
    const from = monitorBox(focused);
    let best = null, intersection = -1;
    monitors.forEach(function (monitor) {
        if (monitor === focused)
            return;
        const to = monitorBox(monitor);
        // Match Hyprland's edge-adjacency tolerance and tie-breaking order.
        if (Math.abs(edgeDistance(direction, from, to)) >= 2)
            return;
        const overlap = edgeOverlap(direction, from, to);
        if (overlap > intersection) {
            best = monitor;
            intersection = overlap;
        }
    });
    return best;
}

function relativeMonitor(selector, monitors) {
    const index = monitors.findIndex(function (monitor) {
        return monitor.focused;
    });
    if (index < 0)
        return null;
    return monitors[(index + Number(selector) % monitors.length + monitors.length) % monitors.length];
}

function descriptionMatches(description, monitor) {
    const shortDescription = [monitor.make || "", monitor.model || "", monitor.serial || ""].join(" ").trim();
    return String(monitor.description || "").startsWith(description) || shortDescription.startsWith(description);
}

function monitorMatches(selector, monitor, monitors) {
    if (selector === "current")
        return !!monitor.focused;
    if (/^[lrudtb]$/.test(selector)) {
        const target = directionalMonitor(selector, monitors);
        return target !== null && target.name === monitor.name;
    }
    if (/^[+-]\d+$/.test(selector)) {
        const target = relativeMonitor(selector, monitors);
        return target !== null && target.name === monitor.name;
    }
    if (/^\d+$/.test(selector))
        return monitor.id === Number(selector);
    if (selector.startsWith("desc:"))
        return descriptionMatches(selector.slice(5).trim(), monitor);
    return monitor.name === selector;
}

function clientMatches(flags, workspace, client) {
    if (!client.workspace || client.workspace.id !== workspace.id || !client.mapped)
        return false;
    if (flags.includes("t") && client.floating)
        return false;
    if (flags.includes("f") && !client.floating)
        return false;
    if (flags.includes("p") && !client.pinned)
        return false;
    return !flags.includes("v") || (!client.hidden && client.visible !== false);
}

function firstInGroup(client, groups) {
    if (!client.grouped || client.grouped.length === 0)
        return false;
    const key = client.grouped.slice().sort().join(",");
    if (groups[key])
        return false;
    groups[key] = true;
    return true;
}

function windowCount(flags, workspace, clients) {
    if (!flags)
        return workspace.windows;
    const groups = {};
    return clients.filter(function (client) {
        if (!clientMatches(flags, workspace, client))
            return false;
        return !flags.includes("g") || firstInGroup(client, groups);
    }).length;
}

function booleanSelector(value) {
    return ["true", "1", "yes", "on"].includes(value);
}
function rangeMatches(value, workspace) {
    const range = value.match(/^(\d+)-(\d+)$/);
    return !!range && workspace.id >= Number(range[1]) && workspace.id <= Number(range[2]);
}
function nameMatches(value, workspace) {
    if (value.startsWith("s:"))
        return workspace.name.startsWith(value.slice(2));
    if (value.startsWith("e:"))
        return workspace.name.endsWith(value.slice(2));
    return (workspace.id <= -1337) === booleanSelector(value);
}
function countMatches(value, workspace, clients) {
    const count = value.match(/^([tfpgv]*)(\d+)(?:-(\d+))?$/);
    if (!count)
        return false;
    const actual = windowCount(count[1], workspace, clients);
    return actual >= Number(count[2]) && actual <= Number(count[3] || count[2]);
}
function fullscreenMatches(value, workspace, clients) {
    if (value === "-1")
        return !workspace.hasfullscreen;
    if (value !== "0" && value !== "1")
        return true;
    const mode = value === "0" ? 2 : 1;
    return clients.some(function (client) {
        return client.workspace && client.workspace.id === workspace.id && client.fullscreen === mode;
    });
}
function termMatches(term, workspace, monitor, snapshot) {
    const value = term.slice(2, -1);
    switch (term[0]) {
    case "r":
        return rangeMatches(value, workspace);
    case "s":
        return (workspace.id < -1 && workspace.id > -1337) === booleanSelector(value);
    case "n":
        return nameMatches(value, workspace);
    case "m":
        return monitorMatches(value, monitor, snapshot.monitors);
    case "w":
        return countMatches(value, workspace, snapshot.clients);
    case "f":
        return fullscreenMatches(value, workspace, snapshot.clients);
    }
    return false;
}

// Evaluate every term; rules are merged by the caller in configuration order.
function workspaceMatches(selector, workspace, monitor, snapshot) {
    selector = String(selector || "").trim();
    if (!selector)
        return true;
    if (/^-?\d+$/.test(selector))
        return workspace.id === Number(selector);
    if (selector.startsWith("name:"))
        return workspace.name === selector.slice(5);
    if (selector.startsWith("special"))
        return workspace.name === selector;
    const terms = selector.match(/[rsnmwf]\[[^\]]*\]/g);
    if (!terms || terms.join("") !== selector.replace(/\s+(?=[rsnmwf]\[)|^\s+|\s+$/g, ""))
        return false;
    return terms.every(function (term) {
        return termMatches(term, workspace, monitor, snapshot);
    });
}
