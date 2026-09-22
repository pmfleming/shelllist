import Shelllist.Core as Core
import "DisplayModel.js" as Model

Core.Provider {
    id: provider
    required property DisplayController controller

    providerId: "displays"
    displayName: qsTr("Displays")
    icon: "󰍹"
    priority: 100
    prefixes: ["displays:"]
    capabilities: ({ query: false, actions: true, preview: true, subscriptions: true })

    function resultsForOutputs(outputs: var): var {
        return outputs.map(function (output) {
            return Core.Model.result({
                providerId: providerId,
                providerPriority: priority,
                id: output.name,
                title: Model.title(output),
                subtitle: output.name + " · " + (output.disabled ? qsTr("Disabled") : qsTr("Enabled")) +
                    (output.width > 0 && output.height > 0 ? " · " + output.width + "×" + output.height + " · " + Number(output.refreshRate).toFixed(2) + " Hz" : ""),
                icon: Model.internal(output.name) ? "󰌢" : "󰍹",
                keywords: [output.name, output.description || "", output.make || "", output.model || "", output.serial || ""],
                score: output.disabled ? 0 : 10,
                primaryActionId: "preview",
                preview: { kind: "display", available: true },
                state: { active: !output.disabled, busy: controller.actionInFlight },
                payload: output
            });
        });
    }
    function liveOutput(result: var): var {
        if (!result || !result.payload) return null;
        return controller.outputs.find(function (output) {
            return output.name === result.id && output.id === result.payload.id;
        }) || null;
    }
    function actionsFor(result: var): var {
        const output = liveOutput(result);
        if (!output) return [];
        const draft = controller.draft.find(function (item) { return item.name === output.name; });
        const browsing = !controller.actionInFlight && !controller.trial && !controller.discardPrompt;
        return [
            Core.Model.keepOpenAction("preview", qsTr("Preview changes"), {
                icon: "󰈈", role: "default", enabled: controller.canPreview && browsing,
                presentation: { group: "primary", tone: "active", width: 170 }
            }),
            Core.Model.keepOpenAction("identify", qsTr("Identify"), {
                icon: "󰈈", enabled: browsing && !output.disabled && controller.stateReady,
                presentation: { group: "toolbar" }
            }),
            Core.Model.keepOpenAction("arrange", qsTr("Arrange"), {
                icon: "󰍹", enabled: browsing,
                presentation: { group: "toolbar" }
            }),
            Core.Model.keepOpenAction("toggle-enabled", draft && draft.enabled ? qsTr("Disable") : qsTr("Enable"), {
                icon: "󰐥", visible: !Model.internal(output.name), enabled: browsing && controller.canEdit && !!draft,
                presentation: { group: "toolbar" }
            })
        ];
    }
    function execute(request: var): bool {
        const output = liveOutput(request ? request.result : null);
        if (!output) return false;
        const action = actionsFor(request.result).find(function (item) { return item.id === request.actionId; });
        if (!action || !action.enabled || !action.visible) return false;
        return controller.executeOutputAction(request.actionId, output.name);
    }
}
