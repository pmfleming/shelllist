import Shelllist.Core as Core
import "DisplayModel.js" as Model

Core.Provider {
    required property DisplayController controller

    providerId: "displays"
    displayName: qsTr("Displays")
    icon: "󰍹"
    priority: 100
    prefixes: ["displays:"]
    capabilities: ({
            query: false,
            actions: true,
            preview: true,
            subscriptions: true
        })

    function stateLabel(output: var): string {
        if (Model.dockedOff(output, controller.displayPolicyState))
            return qsTr("Off · External display preferred");
        if (output.disabled)
            return qsTr("Disabled");
        const source = Model.mirrorSource(output);
        return source ? qsTr("Mirrors %1").arg(source) : qsTr("Extended");
    }
    function resultFor(output: var): var {
        return makeResult({
            id: output.name,
            title: Model.title(output),
            subtitle: [output.name, stateLabel(output), Model.modeSummary(output)].filter(Boolean).join(" · "),
            icon: output.internal ? "󰌢" : "󰍹",
            keywords: [output.name, output.description || "", output.make || "", output.model || "", output.serial || ""],
            score: output.disabled ? 0 : 10,
            primaryActionId: "preview",
            preview: {
                kind: "display",
                available: true
            },
            state: {
                active: !output.disabled,
                busy: controller.actionInFlight
            },
            payload: output
        });
    }
    function liveOutput(result: var): var {
        if (!result || !result.payload)
            return null;
        return controller.outputs.find(function (output) {
            return output.name === result.id && output.id === result.payload.id;
        }) || null;
    }
    function actionsFor(result: var): var {
        const output = liveOutput(result);
        if (!output)
            return [];
        const draft = controller.draft.find(function (item) {
            return item.name === output.name;
        });
        const browsing = !controller.actionInFlight && !controller.trial && !controller.discardPrompt;
        return [Core.Model.keepOpenAction("preview", qsTr("Preview changes"), {
                accessKey: "P",
                icon: "󰈈",
                role: "default",
                enabled: controller.canPreview && browsing,
                presentation: {
                    group: "primary",
                    tone: "active",
                    width: 170
                }
            }), Core.Model.keepOpenAction("identify", qsTr("Identify"), {
                accessKey: "I",
                icon: "filter_1",
                enabled: browsing && !output.disabled && controller.stateReady,
                presentation: {
                    group: "toolbar"
                }
            }), Core.Model.keepOpenAction("toggle-enabled", draft && draft.enabled ? qsTr("Disable") : qsTr("Enable"), {
                accessKey: "E",
                icon: "󰐥",
                visible: true,
                enabled: browsing && controller.canToggleEnabled(output.name),
                presentation: {
                    group: "toolbar"
                }
            })];
    }
    function execute(request: var): bool {
        const output = liveOutput(request ? request.result : null);
        if (!output)
            return false;
        const action = actionsFor(request.result).find(function (item) {
            return item.id === request.actionId;
        });
        if (!action || !action.enabled || !action.visible)
            return false;
        return controller.executeOutputAction(request.actionId, output.name);
    }
}
