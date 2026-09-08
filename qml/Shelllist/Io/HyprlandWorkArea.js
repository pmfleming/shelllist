.pragma library

// hyprctl --batch returns adjacent JSON documents, not a JSON array.
function parseBatch(text) {
    const documents = [];
    let start = -1, depth = 0, quoted = false, escaped = false;
    for (let i = 0; i < text.length; ++i) {
        const c = text[i];
        if (start < 0) {
            if (/\s/.test(c)) continue;
            if (c !== "{" && c !== "[") throw new Error("Invalid Hyprland reply");
            start = i;
        }
        if (quoted) {
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === '"') quoted = false;
        } else if (c === '"') quoted = true;
        else if (c === "{" || c === "[") ++depth;
        else if (c === "}" || c === "]") {
            if (--depth === 0) {
                documents.push(JSON.parse(text.slice(start, i + 1)));
                start = -1;
            }
        }
    }
    if (start >= 0 || documents.length !== 5
            || !documents.slice(0, 4).every(function (list) {
                return Array.isArray(list) && list.every(function (item) {
                    return item !== null && typeof item === "object" && !Array.isArray(item);
                });
            }))
        throw new Error("Incomplete Hyprland geometry snapshot");
    const gaps = cssGaps(documents[4].css);
    if (!gaps) throw new Error("Missing Hyprland outer gaps");
    return { monitors: documents[0], workspaces: documents[1],
        rules: documents[2], clients: documents[3], gaps: gaps };
}

function cssGaps(value) {
    if (value === undefined || value === null || String(value).trim() === "") return null;
    const parts = Array.isArray(value) ? value : String(value).trim().split(/\s+/).map(Number);
    if (parts.length < 1 || parts.length > 4 || !parts.every(Number.isFinite)) return null;
    // Hyprland uses CSS order: top, right, bottom, left.
    return [parts[0], parts.length > 1 ? parts[1] : parts[0],
        parts.length > 2 ? parts[2] : parts[0],
        parts.length > 3 ? parts[3] : parts.length > 1 ? parts[1] : parts[0]];
}

function monitorBox(monitor) {
    const rotated = Number(monitor.transform || 0) % 2 !== 0;
    return { x: monitor.x, y: monitor.y,
        width: Math.round((rotated ? monitor.height : monitor.width) / monitor.scale),
        height: Math.round((rotated ? monitor.width : monitor.height) / monitor.scale) };
}

function directionalMonitor(direction, monitors) {
    const focused = monitors.find(function (m) { return m.focused; });
    if (!focused) return null;
    const from = monitorBox(focused);
    let best = null, intersection = -1;
    monitors.forEach(function (monitor) {
        if (monitor === focused) return;
        const to = monitorBox(monitor);
        const horizontal = direction === "l" || direction === "r";
        const distance = direction === "l" ? from.x - to.x - to.width
            : direction === "r" ? from.x + from.width - to.x
            : direction === "u" || direction === "t" ? from.y - to.y - to.height
            : from.y + from.height - to.y;
        // Same edge-adjacency tolerance used by Hyprland's directional selector.
        if (Math.abs(distance) >= 2) return;
        const overlap = horizontal
            ? Math.max(0, Math.min(from.y + from.height, to.y + to.height) - Math.max(from.y, to.y))
            : Math.max(0, Math.min(from.x + from.width, to.x + to.width) - Math.max(from.x, to.x));
        if (overlap > intersection) { best = monitor; intersection = overlap; }
    });
    return best;
}

function monitorMatches(selector, monitor, monitors) {
    if (selector === "current") return !!monitor.focused;
    if (/^[lrudtb]$/.test(selector)) {
        const target = directionalMonitor(selector, monitors);
        return target !== null && target.name === monitor.name;
    }
    if (/^[+-]\d+$/.test(selector)) {
        const index = monitors.findIndex(function (m) { return m.focused; });
        return index >= 0 && monitors[(index + Number(selector) % monitors.length
            + monitors.length) % monitors.length].name === monitor.name;
    }
    if (/^\d+$/.test(selector)) return monitor.id === Number(selector);
    if (selector.startsWith("desc:")) {
        const description = selector.slice(5).trim();
        const shortDescription = [monitor.make || "", monitor.model || "", monitor.serial || ""].join(" ").trim();
        return String(monitor.description || "").startsWith(description) || shortDescription.startsWith(description);
    }
    return monitor.name === selector;
}

function windowCount(flags, workspace, clients) {
    if (!flags) return workspace.windows;
    const groups = {};
    return clients.filter(function (client) {
        if (!client.workspace || client.workspace.id !== workspace.id || !client.mapped) return false;
        if (flags.includes("t") && client.floating) return false;
        if (flags.includes("f") && !client.floating) return false;
        if (flags.includes("p") && !client.pinned) return false;
        if (flags.includes("v") && (client.hidden || client.visible === false)) return false;
        if (flags.includes("g")) {
            if (!client.grouped || client.grouped.length === 0) return false;
            const key = client.grouped.slice().sort().join(",");
            if (groups[key]) return false;
            groups[key] = true;
        }
        return true;
    }).length;
}

// Workspace rules are merged in configuration order, including dynamic selectors
// (e.g. w[t1] used for smart gaps). Never infer the gap from a particular window.
function workspaceMatches(selector, workspace, monitor, snapshot) {
    selector = String(selector || "").trim();
    if (!selector) return true;
    if (/^-?\d+$/.test(selector)) return workspace.id === Number(selector);
    if (selector.startsWith("name:")) return workspace.name === selector.slice(5);
    if (selector.startsWith("special")) return workspace.name === selector;
    const terms = selector.match(/[rsnmwf]\[[^\]]*\]/g);
    if (!terms || terms.join("") !== selector.replace(/\s+(?=[rsnmwf]\[)|^\s+|\s+$/g, "")) return false;
    return terms.every(function (term) {
        const value = term.slice(2, -1);
        switch (term[0]) {
        case "r": {
            const range = value.match(/^(\d+)-(\d+)$/);
            return !!range && workspace.id >= Number(range[1]) && workspace.id <= Number(range[2]);
        }
        case "s": return (workspace.id < -1 && workspace.id > -1337) === ["true", "1", "yes", "on"].includes(value);
        case "n":
            if (value.startsWith("s:")) return workspace.name.startsWith(value.slice(2));
            if (value.startsWith("e:")) return workspace.name.endsWith(value.slice(2));
            return (workspace.id <= -1337) === ["true", "1", "yes", "on"].includes(value);
        case "m": return monitorMatches(value, monitor, snapshot.monitors);
        case "w": {
            const count = value.match(/^([tfpgv]*)(\d+)(?:-(\d+))?$/);
            if (!count) return false;
            const actual = windowCount(count[1], workspace, snapshot.clients);
            return actual >= Number(count[2]) && actual <= Number(count[3] || count[2]);
        }
        case "f":
            if (value === "-1") return !workspace.hasfullscreen;
            if (value !== "0" && value !== "1") return true;
            return snapshot.clients.some(function (client) {
                return client.workspace && client.workspace.id === workspace.id
                    && client.fullscreen === (value === "0" ? 2 : 1);
            });
        }
        return false;
    });
}

function insets(snapshot, monitorName) {
    if (!snapshot) return null;
    const monitor = snapshot.monitors.find(function (m) { return m.name === monitorName && !m.disabled; });
    if (!monitor || !Array.isArray(monitor.reserved) || monitor.reserved.length !== 4
            || !monitor.reserved.every(Number.isFinite)) return null;
    const active = monitor.specialWorkspace && monitor.specialWorkspace.id !== 0
        ? monitor.specialWorkspace : monitor.activeWorkspace;
    if (!active || !Number.isFinite(active.id)) return null;
    const workspace = snapshot.workspaces.find(function (w) { return w.id === active.id; });
    if (!workspace || typeof workspace.name !== "string") return null;
    let gaps = snapshot.gaps;
    snapshot.rules.forEach(function (rule) {
        if (rule.gapsOut && workspaceMatches(rule.workspaceString, workspace, monitor, snapshot))
            gaps = cssGaps(rule.gapsOut) || gaps;
    });
    // Monitor reservations are left, top, right, bottom, already in logical units.
    // The tiled outer border is at reserved + gaps_out; border_size is NOT added.
    return { left: monitor.reserved[0] + gaps[3], top: monitor.reserved[1] + gaps[0],
        right: monitor.reserved[2] + gaps[1], bottom: monitor.reserved[3] + gaps[2] };
}

function rectangle(screen, margins) {
    if (!margins) return null;
    // QScreen is authoritative for logical size (including rotation and fractional
    // scale). Do not divide its size or Hyprland's reservations by scale again.
    const left = Math.max(0, Math.min(screen.width - 1, Math.round(margins.left)));
    const top = Math.max(0, Math.min(screen.height - 1, Math.round(margins.top)));
    const right = Math.max(0, Math.min(screen.width - left - 1, Math.round(margins.right)));
    const bottom = Math.max(0, Math.min(screen.height - top - 1, Math.round(margins.bottom)));
    return { x: screen.x + left, y: screen.y + top,
        width: screen.width - left - right, height: screen.height - top - bottom,
        left: left, top: top, right: right, bottom: bottom };
}

function geometryEvent(name) {
    return /^(workspace|focusedmon|monitor|configreloaded|openlayer|closelayer|openwindow|closewindow|movewindow|changefloatingmode|fullscreen|activespecial|moveworkspace|renameworkspace|createworkspace|destroyworkspace|togglegroup|moveintogroup|moveoutofgroup|pin)/.test(name);
}
