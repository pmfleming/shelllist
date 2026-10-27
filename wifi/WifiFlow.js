.pragma library
.import "WifiPresentation.js" as Presentation

function mergeNetworkChanges(currentNetworks, event) {
    const removedKeys = new Set((event.removed || []).map(network => network.key).filter(Boolean));
    const replacements = (event.changed || []).concat(event.added || []);
    const byKey = new Map();
    // Preserve first-replacement precedence without searching the whole delta
    // for every existing network. Removal followed by addition remains valid.
    for (const network of replacements) {
        if (!byKey.has(network.key))
            byKey.set(network.key, network);
    }
    const retained = currentNetworks.filter(network => !removedKeys.has(network.key)).map(network => byKey.get(network.key) || network);
    const retainedKeys = new Set(retained.map(network => network.key));
    for (const network of replacements) {
        if (network.key && retainedKeys.has(network.key))
            continue;
        retained.push(network);
        retainedKeys.add(network.key);
    }
    return retained;
}

function bandTransition(event, requestId) {
    if (event.event === "subscribed" || (requestId && event.request_id !== requestId))
        return {
            stage: "ignored"
        };
    if (["started", "progress"].includes(event.event))
        return {
            stage: "running",
            message: event.data.message || "Applying Wi-Fi band selection…"
        };
    if (event.event !== "succeeded")
        return {
            stage: "failed",
            message: event.data.message || (event.event === "cancelled" ? "Wi-Fi band change cancelled" : "Wi-Fi band change failed")
        };
    const result = event.data.result || ({});
    return {
        stage: "completed",
        band: result.band || ({}),
        message: result.message || "Wi-Fi band selection updated"
    };
}

function secretTransition(event, mode, requestId, outcomeRequestId) {
    if (event.event === "requested")
        return {
            stage: "requested"
        };
    if (event.event === "cancelled" && (requestId === event.request_id || outcomeRequestId === event.request_id))
        return {
            stage: "cancelled",
            message: event.data.reason === "activation-finished" ? "" : event.data.reason === "expired" ? "Credential request expired. Select the network and connect again." : "NetworkManager cancelled the Wi-Fi secret request."
        };
    if (event.event === "delivered" && event.request_id === outcomeRequestId)
        return {
            stage: "delivered",
            message: "Credentials sent to NetworkManager; waiting for connection…"
        };
    if (event.event !== "persistence")
        return {
            stage: "ignored"
        };
    return {
        stage: "persistence",
        message: event.data.status === "stored" ? (event.data.storage_provider === "networkmanager" ? "Wi-Fi credentials saved by NetworkManager." : "Wi-Fi credentials saved.") : "Wi-Fi credential storage could not be confirmed: " + (event.data.error || event.data.status)
    };
}

function profileForAccessPoint(ap) {
    if (!ap)
        return null;
    return ap.primary_profile || (ap.profiles && ap.profiles.length > 0 ? ap.profiles[0] : null);
}
function shareHint(ap) {
    return ap && ap.share ? ap.share : ({});
}
function canShareQr(ap) {
    const share = shareHint(ap);
    return !!share.shareable && !!share.qr_payload;
}
function wifiQrPayload(ap) {
    return canShareQr(ap) ? (shareHint(ap).qr_payload || "") : "";
}
