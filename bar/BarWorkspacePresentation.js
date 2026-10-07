.pragma library
.import Shelllist.Core 1.0 as Core

"use strict";
function workspaceIds(state, monitorName) {
    const ids = [1, 2, 3, 4, 5];
    const seen = ({ 1: true, 2: true, 3: true, 4: true, 5: true });
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    workspaces.forEach(function (workspace) {
        if (workspace.id > 0 && workspace.monitor === monitorName && !seen[workspace.id]) {
            seen[workspace.id] = true;
            ids.push(workspace.id);
        }
    });
    return ids.sort(function (left, right) { return left - right; });
}
function workspaceFor(state, workspaceId) {
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    return workspaces.find(function (workspace) { return workspace.id === workspaceId; }) || null;
}
function activeWorkspaceId(state, monitorName) {
    const monitors = state && Array.isArray(state.monitors) ? state.monitors : [];
    const monitor = monitors.find(function (candidate) { return candidate.name === monitorName; });
    return monitor ? monitor.active_workspace_id : 0;
}
function activeWorkspaceIndex(state, monitorName) {
    return workspaceIds(state, monitorName).indexOf(activeWorkspaceId(state, monitorName));
}
function workspaceCategory(workspaceId) {
    return Core.WorkspaceCategories.categories.find(category => Number(category.workspace) === workspaceId) || null;
}
