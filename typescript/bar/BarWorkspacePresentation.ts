function workspaceIds(state: any, monitorName: any) {
    const ids = [1, 2, 3, 4, 5];
    const seen: Record<number, boolean> = ({ 1: true, 2: true, 3: true, 4: true, 5: true });
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    workspaces.forEach(function (workspace: any) {
        if (workspace.id > 0 && workspace.monitor === monitorName && !seen[workspace.id]) {
            seen[workspace.id] = true;
            ids.push(workspace.id);
        }
    });
    return ids.sort(function (left: any, right: any) { return left - right; });
}

function workspaceFor(state: any, workspaceId: any) {
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    return workspaces.find(function (workspace: any) { return workspace.id === workspaceId; }) || null;
}

function activeWorkspaceId(state: any, monitorName: any) {
    const monitors = state && Array.isArray(state.monitors) ? state.monitors : [];
    const monitor = monitors.find(function (candidate: any) { return candidate.name === monitorName; });
    return monitor ? monitor.active_workspace_id : 0;
}

function activeWorkspaceIndex(state: any, monitorName: any) {
    return workspaceIds(state, monitorName).indexOf(activeWorkspaceId(state, monitorName));
}

function workspaceGlyph(workspaceId: any) {
    return workspaceId === 1 ? "󰊠" : workspaceId > 5 ? String(workspaceId) : "";
}

function workspaceIconName(workspaceId: any) {
    const icons: Record<number, string> = {
        2: "zen",
        3: "vscode",
        4: "spotify-client",
        5: "scratchpad"
    };
    return icons[workspaceId] || "";
}

function activeWindowFor(state: any, monitorName: any) {
    if (!state || !state.active_window)
        return null;
    const focusedMonitor = String(state.focused_monitor || "");
    return focusedMonitor.length === 0 || focusedMonitor === monitorName
        ? state.active_window : null;
}

function windowIconName(window: any) {
    if (!window)
        return "application-x-executable";
    const value = String(window.initial_class || window.class_name || "").trim();
    return value.length > 0 ? value : "application-x-executable";
}
