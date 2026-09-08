.pragma library
.import "HyprlandWorkspaceRules.js" as WorkspaceRules

function advanceString(state, character) {
    if (!state.quoted) {
        state.quoted = character === '"';
        return state.quoted;
    }
    if (state.escaped)
        state.escaped = false;
    else if (character === "\\")
        state.escaped = true;
    else if (character === '"')
        state.quoted = false;
    return true;
}

function documentEnd(text, start) {
    const state = {
        quoted: false,
        escaped: false
    };
    let depth = 0;
    for (let index = start; index < text.length; ++index) {
        const character = text[index];
        if (advanceString(state, character))
            continue;
        if (character === "{" || character === "[")
            ++depth;
        else if (character === "}" || character === "]") {
            if (--depth === 0)
                return index + 1;
        }
    }
    throw new Error("Incomplete Hyprland geometry snapshot");
}

function jsonDocuments(text) {
    const documents = [];
    for (let index = 0; index < text.length; ) {
        if (/\s/.test(text[index])) {
            ++index;
            continue;
        }
        if (text[index] !== "{" && text[index] !== "[")
            throw new Error("Invalid Hyprland reply");
        const end = documentEnd(text, index);
        documents.push(JSON.parse(text.slice(index, end)));
        index = end;
    }
    return documents;
}

function objectList(value) {
    return Array.isArray(value) && value.every(function (item) {
        return item !== null && typeof item === "object" && !Array.isArray(item);
    });
}

// hyprctl --batch returns adjacent JSON documents, not a JSON array.
function parseBatch(text) {
    const documents = jsonDocuments(text);
    if (documents.length !== 5 || !documents.slice(0, 4).every(objectList))
        throw new Error("Incomplete Hyprland geometry snapshot");
    const gaps = cssGaps(documents[4].css);
    if (!gaps)
        throw new Error("Missing Hyprland outer gaps");
    return {
        monitors: documents[0],
        workspaces: documents[1],
        rules: documents[2],
        clients: documents[3],
        gaps: gaps
    };
}

function cssGaps(value) {
    if (value === undefined || value === null || String(value).trim() === "")
        return null;
    const parts = Array.isArray(value) ? value : String(value).trim().split(/\s+/).map(Number);
    if (parts.length < 1 || parts.length > 4 || !parts.every(Number.isFinite))
        return null;
    // Hyprland uses CSS order: top, right, bottom, left.
    return [parts[0], parts.length > 1 ? parts[1] : parts[0], parts.length > 2 ? parts[2] : parts[0], parts.length > 3 ? parts[3] : parts.length > 1 ? parts[1] : parts[0]];
}

function monitorBox(monitor) {
    return WorkspaceRules.monitorBox(monitor);
}
function directionalMonitor(direction, monitors) {
    return WorkspaceRules.directionalMonitor(direction, monitors);
}
function monitorMatches(selector, monitor, monitors) {
    return WorkspaceRules.monitorMatches(selector, monitor, monitors);
}
function windowCount(flags, workspace, clients) {
    return WorkspaceRules.windowCount(flags, workspace, clients);
}
function workspaceMatches(selector, workspace, monitor, snapshot) {
    return WorkspaceRules.workspaceMatches(selector, workspace, monitor, snapshot);
}

function insets(snapshot, monitorName) {
    if (!snapshot)
        return null;
    const monitor = snapshot.monitors.find(function (m) {
        return m.name === monitorName && !m.disabled;
    });
    if (!monitor || !Array.isArray(monitor.reserved) || monitor.reserved.length !== 4 || !monitor.reserved.every(Number.isFinite))
        return null;
    const active = monitor.specialWorkspace && monitor.specialWorkspace.id !== 0 ? monitor.specialWorkspace : monitor.activeWorkspace;
    if (!active || !Number.isFinite(active.id))
        return null;
    const workspace = snapshot.workspaces.find(function (w) {
        return w.id === active.id;
    });
    if (!workspace || typeof workspace.name !== "string")
        return null;
    let gaps = snapshot.gaps;
    snapshot.rules.forEach(function (rule) {
        if (rule.gapsOut && workspaceMatches(rule.workspaceString, workspace, monitor, snapshot))
            gaps = cssGaps(rule.gapsOut) || gaps;
    });
    // Reservations are left, top, right, bottom, already in logical units.
    // The tiled outer border is at reserved + gaps_out; border_size is NOT added.
    return {
        left: monitor.reserved[0] + gaps[3],
        top: monitor.reserved[1] + gaps[0],
        right: monitor.reserved[2] + gaps[1],
        bottom: monitor.reserved[3] + gaps[2]
    };
}

function rectangle(screen, margins) {
    if (!margins)
        return null;
    // QScreen is authoritative for logical size, including fractional scale.
    const left = Math.max(0, Math.min(screen.width - 1, Math.round(margins.left)));
    const top = Math.max(0, Math.min(screen.height - 1, Math.round(margins.top)));
    const right = Math.max(0, Math.min(screen.width - left - 1, Math.round(margins.right)));
    const bottom = Math.max(0, Math.min(screen.height - top - 1, Math.round(margins.bottom)));
    return {
        x: screen.x + left,
        y: screen.y + top,
        width: screen.width - left - right,
        height: screen.height - top - bottom,
        left: left,
        top: top,
        right: right,
        bottom: bottom
    };
}

function geometryEvent(name) {
    return /^(workspace|focusedmon|monitor|configreloaded|openlayer|closelayer|openwindow|closewindow|movewindow|changefloatingmode|fullscreen|activespecial|moveworkspace|renameworkspace|createworkspace|destroyworkspace|togglegroup|moveintogroup|moveoutofgroup|pin)/.test(name);
}
