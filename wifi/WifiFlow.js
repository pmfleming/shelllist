.pragma library
.import "WifiPresentation.js" as Presentation

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
