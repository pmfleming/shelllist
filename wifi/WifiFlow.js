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

function powerStatus(activeStatus, radios, enabled) {
    const nextRadios = Object.assign({}, radios, {
        wireless_enabled: enabled
    });
    const current = activeStatus || ({});
    return Object.assign({}, current, {
        enabled: enabled,
        radios: nextRadios,
        active: enabled ? !!current.active : false
    });
}

function bandTransition(event, requestId) {
    if (event.event === "subscribed" || (requestId && event.request_id !== requestId))
        return {
            stage: "ignored"
        };
    if (["started", "progress"].includes(event.event))
        return {
            stage: "running",
            message: event.message || "Applying Wi-Fi band selection…"
        };
    if (event.event !== "succeeded")
        return {
            stage: "failed",
            message: event.message || (event.event === "cancelled" ? "Wi-Fi band change cancelled" : "Wi-Fi band change failed")
        };
    const result = event.result || ({});
    return {
        stage: "completed",
        band: result.band || ({}),
        message: result.message || "Wi-Fi band selection updated"
    };
}

function secretTransition(event, mode, requestId) {
    if (event.event === "requested")
        return {
            stage: "requested"
        };
    if (event.event === "cancelled" && mode === "daemon-secret" && requestId === event.request_id)
        return {
            stage: "cancelled",
            message: "NetworkManager cancelled the Wi-Fi secret request."
        };
    if (event.event !== "persistence")
        return {
            stage: "ignored"
        };
    return {
        stage: "persistence",
        message: event.status === "stored" ? "Wi-Fi secret saved to the keyring." : "Wi-Fi secret was accepted but could not be saved: " + event.status
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

function isWrongPasswordReason(reason) {
    return reason === "wrong-password";
}
function isSecretFailureReason(reason) {
    return isWrongPasswordReason(reason) || reason === "password-unavailable" || reason === "secret-required";
}

function portalNetworkIdentity(ap, result) {
    const profile = profileForAccessPoint(ap);
    return (ap && ap.key) || (profile && profile.path) || Presentation.valueOr(result, "ssid", Presentation.networkName(ap));
}
function confirmedPortalResult(result) {
    return !!(result && result.suggest_open_portal);
}
function portalConnectivity(result, currentConnectivity, activeStatus) {
    return Presentation.valueOr(result, "connectivity", currentConnectivity || Presentation.valueOr(activeStatus, "connectivity", ({})));
}
function portalEpisode(automatic, identity, requestId) {
    return automatic ? identity + "::" + requestId : "";
}
// NetworkManager's connectivity-check URI, when the daemon reported one.
function portalCheckUri(connectivity) {
    return (connectivity && connectivity.check_uri) || "";
}
// Identity of the connection the portal verdict applies to.
function portalPrimaryConnection(connectivity) {
    const primary = (connectivity && connectivity.primary_connection) || null;
    if (!primary)
        return "";
    return primary.id || primary.device_iface || primary.uuid || "";
}
