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

    function action(id: string, label: string, options: var): var {
        return Core.Model.action(Object.assign({
            id: id, label: label, closePolicy: "close",
            presentation: { group: "overflow", tone: "normal", width: 120 }
        }, options || ({})));
    }

    function primaryActions(application: var, busy: bool): var {
        const actions = [action("activate", application.running ? "Focus" : "Launch", {
            icon: application.running ? "󰖲" : "󰐕", shortcut: "Enter", role: "default", enabled: !busy,
            presentation: { group: "primary", tone: "active", width: 128 }
        })];
        if (application.kind === "desktop-application")
            actions.push(action("launch", "Launch new", {
                icon: "󰐕", shortcut: "Shift+Enter", enabled: !busy,
                presentation: { group: "toolbar", tone: "normal", width: 120 }
            }));
        return actions;
    }

    function windowActions(application: var, busy: bool): var {
        return (application.instances || []).map(function (window, index) {
            return action("focus-window-" + index, window.title || "Window", {
                icon: "󰖲", enabled: !busy,
                presentation: { group: "overflow", tone: window.focused ? "active" : "normal", width: 0 },
                metadata: { operation: "focus-window", windowId: window.id }
            });
        });
    }

    function desktopActions(application: var, busy: bool): var {
        return (application.desktop_actions || []).map(function (desktopAction, index) {
            return action("desktop-action-" + index, desktopAction.name || "Application action", {
                icon: desktopAction.icon || "󰐕", enabled: !busy,
                presentation: { group: "overflow", tone: "normal", width: 0 },
                metadata: { operation: "desktop-action", desktopActionId: desktopAction.id }
            });
        });
    }

    function actionsForApplication(application: var): var {
        if (!application)
            return [];
        const busy = controller.actionInFlight;
        return primaryActions(application, busy)
            .concat(windowActions(application, busy), desktopActions(application, busy));
    }

    function subtitleFor(application: var): string {
        const running = application.running_count || 0;
        if (running > 0)
            return running === 1 ? "Running" : running + " windows";
        return application.generic_name || application.comment || "Application";
    }

    function keywordsFor(application: var): var {
        const keywords = [application.id, application.generic_name, application.comment,
            application.startup_class].concat(application.keywords || [], application.categories || []);
        (application.instances || []).forEach(function (window) {
            keywords.push(window.title, window.class);
        });
        return keywords;
    }

    function badgesFor(application: var): var {
        if (application.focused)
            return ["focused"];
        return application.running ? ["running"] : [];
    }

    function resultForApplication(application: var): var {
        return Core.Model.result({
            providerId: providerId, providerPriority: priority, id: application.id,
            title: application.name, subtitle: subtitleFor(application),
            icon: application.icon || "application-x-executable", score: application.score || 0,
            keywords: keywordsFor(application), badges: badgesFor(application),
            primaryActionId: "activate", actions: [], preview: { kind: "application", available: true },
            state: { active: !!application.focused,
                busy: controller.actionInFlight && controller.activeTargetId === application.id },
            payload: application
        });
    }

    function resultsForApplications(applications: var): var {
        return (applications || []).map(function (application) { return provider.resultForApplication(application); });
    }
    function query(request: var): void { controller.requestApplications(request.id, request.text, request.generation, request.limit); }
    function cancel(requestId: string): void { controller.cancelQuery(requestId); }
    function actionsFor(result: var): var { return result && result.payload ? actionsForApplication(result.payload) : []; }
    function primaryActionIdFor(result: var): string { return "activate"; }

    function operationFor(actionId: string): string {
        if (actionId.indexOf("focus-window-") === 0)
            return "focus-window";
        if (actionId.indexOf("desktop-action-") === 0)
            return "desktop-action";
        return actionId;
    }

    function execute(request: var): bool {
        if (!request || !request.result || !request.result.payload)
            return false;
        const metadata = request.action.metadata || ({});
        executionStarted(request);
        return controller.executeProviderAction(request, {
            target_id: request.result.id,
            action: operationFor(request.actionId),
            window_id: metadata.windowId || null,
            desktop_action_id: metadata.desktopActionId || null,
            expected_revision: request.result.payload.revision || null,
            workspace_id: controller.currentWorkspaceId || null
        });
    }
}
