interface Workspace {
    id: number;
    monitor?: string;
}
interface Monitor {
    name?: string;
    active_workspace_id: number;
}
interface WorkspaceCategory {
    value: string; label: string; icon: string; workspace: string;
}
declare const Core: {WorkspaceCategories: {categories: WorkspaceCategory[]}};
interface WorkspaceState {
    workspaces?: Workspace[];
    monitors?: Monitor[];
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

function workspaceCategory(workspaceId: number): WorkspaceCategory | null {
    return Core.WorkspaceCategories.categories.find(category => Number(category.workspace) === workspaceId) || null;
}
