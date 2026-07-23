import Shelllist.Core as Core
import "ClipApi.js" as ClipApi

Core.Provider {
    id: provider

    required property ClipboardController controller

    providerId: "clipboard"
    displayName: "Clipboard"
    icon: "󰅇"
    priority: 100
    prefixes: ["clipboard:", "clip:"]
    capabilities: ({ query: true, actions: true, preview: true, subscriptions: true })

    function iconFor(kind) {
        const icons = {
            text: "󰦨", link: "󰌷", image: "󰋩", files: "󰉋",
            html: "󰌝", json: "󰘦", color: "󰏘", binary: "󰞷"
        };
        return icons[kind] || icons.binary;
    }
    function labelFor(kind) {
        const value = String(kind || "binary");
        return value.charAt(0).toUpperCase() + value.slice(1);
    }
    function resultForEntry(entry) {
        const kind = entry.kind || "binary";
        const preview = entry.preview || labelFor(kind) + " clipboard entry";
        return Core.Model.result({
            providerId: providerId,
            providerPriority: priority,
            id: entry.id,
            title: preview,
            subtitle: labelFor(kind) + " · " + (entry.mime || "unknown") + " · " + entry.byte_size + " bytes",
            icon: iconFor(kind),
            score: entry.current ? 2000 : (entry.favorite ? 1000 : 100),
            keywords: [preview, entry.mime || "", kind],
            badges: entry.current ? ["current"] : (entry.favorite ? ["favorite"] : []),
            primaryActionId: kind === "binary" ? "copy" : "paste",
            actions: ClipApi.actionsForKind(kind),
            preview: { kind: "clipboard-entry", available: true },
            state: { active: false, busy: false },
            payload: entry
        });
    }
    function resultsForEntries(entries) {
        return (entries || []).map(function (entry) { return provider.resultForEntry(entry); });
    }
    function query(request) {
        controller.requestHistory(request.id, request.text, request.generation, request.limit);
    }
    function cancel(requestId) { controller.cancelQuery(requestId); }
}
