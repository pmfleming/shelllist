interface Workspace {
    id: number;
    monitor?: string;
}
interface Monitor {
    name?: string;
    active_workspace_id: number;
}
interface ActiveWindow {
    initial_class?: string;
    class_name?: string;
}
interface WorkspaceState {
    workspaces?: Workspace[];
    monitors?: Monitor[];
    focused_monitor?: string;
    active_window?: ActiveWindow | null;
}
type Maybe<T> = T | null | undefined;

function workspaceIds(state: Maybe<WorkspaceState>, monitorName: string) {
    const ids = [1, 2, 3, 4, 5];
    const seen: Record<number, boolean> = ({ 1: true, 2: true, 3: true, 4: true, 5: true });
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    workspaces.forEach(function (workspace: Workspace) {
        if (workspace.id > 0 && workspace.monitor === monitorName && !seen[workspace.id]) {
            seen[workspace.id] = true;
            ids.push(workspace.id);
        }
    });
    return ids.sort(function (left: number, right: number) { return left - right; });
}

function workspaceFor(state: Maybe<WorkspaceState>, workspaceId: number) {
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    return workspaces.find(function (workspace: Workspace) { return workspace.id === workspaceId; }) || null;
}

function activeWorkspaceId(state: Maybe<WorkspaceState>, monitorName: string) {
    const monitors = state && Array.isArray(state.monitors) ? state.monitors : [];
    const monitor = monitors.find(function (candidate: Monitor) { return candidate.name === monitorName; });
    return monitor ? monitor.active_workspace_id : 0;
}

function activeWorkspaceIndex(state: Maybe<WorkspaceState>, monitorName: string) {
    return workspaceIds(state, monitorName).indexOf(activeWorkspaceId(state, monitorName));
}

function workspaceGlyph(workspaceId: number) {
    return workspaceId === 1 ? "󰊠" : workspaceId > 5 ? String(workspaceId) : "";
}

function workspaceIconName(workspaceId: number) {
    const icons: Record<number, string> = {
        2: "zen",
        3: "vscode",
        4: "spotify-client",
        5: "scratchpad"
    };
    return icons[workspaceId] || "";
}

function activeWindowFor(state: Maybe<WorkspaceState>, monitorName: string) {
    if (!state || !state.active_window)
        return null;
    const focusedMonitor = String(state.focused_monitor || "");
    return focusedMonitor.length === 0 || focusedMonitor === monitorName
        ? state.active_window : null;
}

function windowIconName(window: Maybe<ActiveWindow>) {
    if (!window)
        return "application-x-executable";
    const value = String(window.initial_class || window.class_name || "").trim();
    return value.length > 0 ? value : "application-x-executable";
}
