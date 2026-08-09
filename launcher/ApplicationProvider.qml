import QtQuick
import Shelllist.Core as Core

Core.Provider {
    id: provider

    required property ApplicationController controller

    providerId: "applications"
    displayName: "Applications"
    icon: "󰀻"
    priority: 100
    prefixes: ["app:"]
    capabilities: ({ query: true, actions: true, preview: true, subscriptions: true })

    function action(id, label, options) {
        return Core.Model.action(Object.assign({
            id: id, label: label, closePolicy: "close",
            presentation: { group: "overflow", tone: "normal", width: 120 }
        }, options || ({})));
    }
    function actionsForApplication(application) {
        if (!application)
            return [];
        const busy = controller.actionInFlight;
        const actions = [action("activate", application.running ? "Focus" : "Launch", {
            icon: application.running ? "󰖲" : "󰐕", shortcut: "Enter", role: "default", enabled: !busy,
            presentation: { group: "primary", tone: "active", width: 128 }
        })];
        if (application.kind === "desktop-application")
            actions.push(action("launch", "Launch new", {
                icon: "󰐕", shortcut: "Shift+Enter", enabled: !busy,
                presentation: { group: "toolbar", tone: "normal", width: 120 }
            }));
        (application.instances || []).forEach(function (window, index) {
            actions.push(action("focus-window-" + index, window.title || "Window", {
                icon: "󰖲", enabled: !busy,
                presentation: { group: "overflow", tone: window.focused ? "active" : "normal", width: 0 },
                metadata: { operation: "focus-window", windowId: window.id }
            }));
        });
        (application.desktop_actions || []).forEach(function (desktopAction, index) {
            actions.push(action("desktop-action-" + index, desktopAction.name || "Application action", {
                icon: desktopAction.icon || "󰐕", enabled: !busy,
                presentation: { group: "overflow", tone: "normal", width: 0 },
                metadata: { operation: "desktop-action", desktopActionId: desktopAction.id }
            }));
        });
        return actions;
    }
    function resultForApplication(application) {
        const running = application.running_count || 0;
        let subtitle = application.generic_name || application.comment || "Application";
        if (running > 0)
            subtitle = running === 1 ? "Running" : running + " windows";
        const keywords = [application.id, application.generic_name, application.comment,
            application.startup_class].concat(application.keywords || [], application.categories || []);
        (application.instances || []).forEach(function (window) { keywords.push(window.title, window.class); });
        return Core.Model.result({
            providerId: providerId, providerPriority: priority, id: application.id,
            title: application.name, subtitle: subtitle, icon: application.icon || "application-x-executable",
            score: application.score || 0, keywords: keywords,
            badges: application.focused ? ["focused"] : (application.running ? ["running"] : []),
            primaryActionId: "activate", actions: [], preview: { kind: "application", available: true },
            state: { active: !!application.focused, busy: controller.actionInFlight && controller.activeTargetId === application.id },
            payload: application
        });
    }
    function resultsForApplications(applications) {
        return (applications || []).map(function (application) { return provider.resultForApplication(application); });
    }
    function query(request) {
        controller.requestApplications(request.id, request.text, request.generation, request.limit);
    }
    function cancel(requestId) { controller.cancelQuery(requestId); }
    function actionsFor(result) { return result && result.payload ? actionsForApplication(result.payload) : []; }
    function primaryActionIdFor(result) { return "activate"; }
    function execute(request) {
        if (!request || !request.result || !request.result.payload)
            return false;
        const metadata = request.action.metadata || ({});
        let operation = request.actionId;
        if (operation.indexOf("focus-window-") === 0)
            operation = "focus-window";
        else if (operation.indexOf("desktop-action-") === 0)
            operation = "desktop-action";
        executionStarted(request);
        return controller.executeProviderAction(request, {
            target_id: request.result.id,
            action: operation,
            window_id: metadata.windowId || null,
            desktop_action_id: metadata.desktopActionId || null,
            expected_revision: request.result.payload.revision || null,
            workspace_id: controller.currentWorkspaceId || null
        });
    }
}
