.pragma library
.import "WifiPresentation.js" as Presentation

function mergeNetworkChanges(currentNetworks, event) {
    const removedKeys = (event.removed || []).map(function (network) {
        return network.key;
    }).filter(Boolean);
    const replacements = (event.changed || []).concat(event.added || []);
    const retained = currentNetworks.filter(function (network) {
        return !removedKeys.includes(network.key);
    }).map(function (network) {
        return replacements.find(function (candidate) {
            return candidate.key === network.key;
        }) || network;
    });
    const retainedKeys = retained.map(function (network) { return network.key; });
    const additions = (event.added || []).filter(function (network) {
        return !network.key || !retainedKeys.includes(network.key);
    });
    return retained.concat(additions);
}

function powerStatus(activeStatus, radios, enabled) {
    const nextRadios = Object.assign({}, radios, { wireless_enabled: enabled });
    const current = activeStatus || ({});
    return Object.assign({}, current, {
        enabled: enabled,
        radios: nextRadios,
        active: enabled ? !!current.active : false
    });
}

function bandTransition(event, requestId) {
    if (event.event === "subscribed" || (requestId && event.request_id !== requestId))
        return { stage: "ignored" };
    if (["started", "progress"].includes(event.event))
        return { stage: "running", message: event.message || "Applying Wi-Fi band selection…" };
    if (event.event !== "succeeded")
        return { stage: "failed", message: event.message
            || (event.event === "cancelled" ? "Wi-Fi band change cancelled" : "Wi-Fi band change failed") };
    const result = event.result || ({});
    return { stage: "completed", band: result.band || ({}),
        message: result.message || "Wi-Fi band selection updated" };
}

function secretTransition(event, mode, requestId) {
    if (event.event === "requested")
        return { stage: "requested" };
    if (event.event === "cancelled" && mode === "daemon-secret" && requestId === event.request_id)
        return { stage: "cancelled", message: "NetworkManager cancelled the Wi-Fi secret request." };
    if (event.event !== "persistence")
        return { stage: "ignored" };
    return { stage: "persistence", message: event.status === "stored"
        ? "Wi-Fi secret saved to the keyring."
        : "Wi-Fi secret was accepted but could not be saved: " + event.status };
}

function profileForAccessPoint(ap) {
    if (!ap)
        return null;
    return ap.primary_profile || (ap.profiles && ap.profiles.length > 0 ? ap.profiles[0] : null);
}
function shareHint(ap) { return ap && ap.share ? ap.share : ({}); }
function canShareQr(ap) {
    const share = shareHint(ap);
    return !!share.shareable && !!share.qr_payload;
}
function wifiQrPayload(ap) { return canShareQr(ap) ? (shareHint(ap).qr_payload || "") : ""; }
function shareAvailability(ap, profile, fallbackMessage) {
    const share = shareHint(ap);
    if (canShareQr(ap))
        return { state: "ready", available: true, payload: wifiQrPayload(ap), message: "Wi-Fi QR payload is ready." };
    const profilePath = share.profile_path || (profile && profile.path) || "";
    if (!share.requires_profile_secret_check || profilePath.length === 0)
        return { state: "unavailable", available: false, payload: "", message: share.reason || fallbackMessage };
    return { state: "check", profilePath: profilePath };
}
function shareCheckAvailability(result, fallbackMessage) {
    const available = !!result.shareable && !!result.qr_payload;
    return {
        path: result.path || "",
        available: available,
        payload: available ? result.qr_payload : "",
        message: available ? "Wi-Fi QR payload is ready." : (result.reason || fallbackMessage)
    };
}

function networkKey(ap) {
    if (ap && ap.key)
        return ap.key;
    return "hidden:" + (ap && ap.ssid ? ap.ssid : "") + "\n" + (ap && ap.security ? ap.security : "");
}
function secretKey(ap) { return networkKey(ap); }
function connectAttemptKey(ap) { return networkKey(ap); }
function passwordFingerprint(password) {
    if (password === undefined || password === null)
        return "saved";
    let hash = 0;
    for (let i = 0; i < password.length; i++)
        hash = ((hash << 5) - hash + password.charCodeAt(i)) | 0;
    return "pw:" + password.length + ":" + hash;
}
function isWrongPasswordReason(reason) { return reason === "wrong-password"; }
function isSecretFailureReason(reason) { return isWrongPasswordReason(reason) || reason === "password-unavailable" || reason === "secret-required"; }
function connectFailureRetryMs(reason) { return isWrongPasswordReason(reason) ? 10000 : 0; }

function portalNetworkIdentity(ap, result) {
    const profile = profileForAccessPoint(ap);
    return (ap && ap.key) || (profile && profile.path) || Presentation.valueOr(result, "ssid", Presentation.networkName(ap));
}
function confirmedPortalResult(result) { return !!(result && result.suggest_open_portal); }
function portalConnectivity(result, currentConnectivity, activeStatus) {
    return Presentation.valueOr(result, "connectivity", currentConnectivity || Presentation.valueOr(activeStatus, "connectivity", ({})));
}
function portalEpisode(automatic, identity, requestId) { return automatic ? identity + "::" + requestId : ""; }
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
