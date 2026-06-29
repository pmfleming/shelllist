.pragma library

function clampIndex(index, length) { return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1)); }
function networkName(ap) { return ap && ap.ssid ? ap.ssid : "<hidden>"; }
function securityLabel(security) { return security === "--" ? "Open" : (security || "Unknown"); }
function hasNetworkIdentity(ap) { return !!(ap && ((ap.ssid_bytes && ap.ssid_bytes.length > 0) || (ap.ssid && ap.ssid.length > 0))); }
function canConnect(ap) { return !!ap && (ap.capabilities ? ap.capabilities.can_connect : hasNetworkIdentity(ap)); }
function needsPassword(ap) { return !!(ap && hasNetworkIdentity(ap) && ap.capabilities && ap.capabilities.needs_password); }
function needsCredentials(ap) { return !!(ap && hasNetworkIdentity(ap) && ap.capabilities && ap.capabilities.needs_credentials); }
function canStartConnection(ap) { return canConnect(ap) || needsPassword(ap) || needsCredentials(ap); }
function accessPointPath(ap) { return ap ? (ap.path || ap.ap_path || "") : ""; }
function subnetLabel(ip4) { return ip4 && ip4.prefix !== null && ip4.prefix !== undefined ? "/" + ip4.prefix : "—"; }
function dnsLabel(ip4) { return ip4 && ip4.dns && ip4.dns.length > 0 ? ip4.dns.join(", ") : "—"; }
function hasNumber(value) { return value !== null && value !== undefined && !isNaN(value); }
function privacyFor(profile) { return profile && profile.privacy ? profile.privacy : ({}); }
function isOpenNetwork(ap) { return !!(ap && ap.security === "--" && hasNetworkIdentity(ap)); }
function canShareQr(ap) { return isOpenNetwork(ap); }

function apiData(response, key) {
    if (!response || response.protocol !== "nm-api")
        return key ? response[key] : response;
    if (response.version !== 1)
        throw new Error("Unsupported nm-api protocol version " + response.version);
    if (!response.ok) {
        const error = response.error || {};
        throw new Error((error.code || "api-error") + ": " + (error.message || "nm-api request failed"));
    }
    const data = response.data || {};
    return key ? data[key] : data;
}

function apiResult(response, key) {
    if (!response || response.protocol !== "nm-api")
        return key ? response[key] : response;
    if (response.version !== 1)
        throw new Error("Unsupported nm-api protocol version " + response.version);
    const data = response.data || {};
    if (!response.ok && data[key])
        return data[key];
    if (!response.ok) {
        const error = response.error || {};
        return { status: "error", reason: error.code || "unknown", message: error.message || "nm-api request failed" };
    }
    return key ? data[key] : data;
}

function escapeWifiQr(value) {
    return (value || "").replace(/([\\;,:\"])/g, "\\$1");
}

function wifiQrPayload(ap) {
    if (!canShareQr(ap))
        return "";
    const hidden = ap.hidden ? ";H:true" : "";
    return "WIFI:T:nopass;S:" + escapeWifiQr(networkName(ap)) + hidden + ";;";
}

function sameAccessPoint(left, right) {
    if (!left || !right)
        return false;
    const leftPath = accessPointPath(left);
    const rightPath = accessPointPath(right);
    if (leftPath && rightPath)
        return leftPath === rightPath;
    if (left.bssid && right.bssid)
        return left.bssid === right.bssid;
    return hasNetworkIdentity(left) && hasNetworkIdentity(right)
        && (left.ssid || "") === (right.ssid || "")
        && (left.security || "") === (right.security || "");
}

function frequencyLabel(ap) {
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    if (frequency <= 0)
        return "Unknown";
    const band = frequency >= 5925 ? "6 GHz" : frequency >= 4900 ? "5 GHz" : "2.4 GHz";
    return band + " (" + frequency + " MHz)";
}

function wifiType(ap) {
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    return frequency >= 5925 ? "Wi-Fi 6E/7" : frequency >= 4900 ? "Wi-Fi 5/6" : frequency > 0 ? "Wi-Fi 4/6" : "Unknown";
}

function detailConnectionStatus(controller) {
    const ap = controller.detailAp;
    if (controller.isActive(ap) && controller.activeStatus)
        return controller.activeStatus;
    return ap && ap.last_connection ? ap.last_connection : null;
}

function detailIp4(controller) {
    const status = detailConnectionStatus(controller);
    return status && status.ip4 ? status.ip4 : null;
}

function activeIp4Value(controller, field) {
    const ip4 = detailIp4(controller);
    return ip4 && ip4[field] ? ip4[field] : "—";
}

function activeDetailValue(controller, value) {
    return detailConnectionStatus(controller) ? value : "—";
}

function wirelessStatus(controller) {
    const status = detailConnectionStatus(controller);
    return status && status.wireless ? status.wireless : null;
}

function hasDirectionalBitrates(controller) {
    const wireless = wirelessStatus(controller);
    return !!(wireless && (hasNumber(wireless.tx_bitrate_mbps) || hasNumber(wireless.rx_bitrate_mbps)));
}

function bitrateLabel(controller) {
    const wireless = wirelessStatus(controller);
    return wireless ? formatMbps(wireless.bitrate_mbps) : "—";
}

function txBitrateLabel(controller) {
    const wireless = wirelessStatus(controller);
    return wireless ? formatMbps(wireless.tx_bitrate_mbps) : "—";
}

function rxBitrateLabel(controller) {
    const wireless = wirelessStatus(controller);
    return wireless ? formatMbps(wireless.rx_bitrate_mbps) : "—";
}

function macLabel(controller) {
    const wireless = wirelessStatus(controller);
    return wireless && wireless.mac_address ? wireless.mac_address : "—";
}

function networkUsageLabel(activeStatus) {
    const metered = activeStatus && activeStatus.metered ? activeStatus.metered : null;
    const labels = { yes: "Metered", no: "Unmetered", "guess-yes": "Probably metered", "guess-no": "Probably unmetered" };
    return metered ? (labels[metered.state] || "Unknown") : "—";
}

function lastSeenLabel(ap) {
    if (!ap || ap.last_seen < 0)
        return "";
    if (!hasNumber(ap.last_seen_age_ms))
        return "Last seen: scan result available";
    const seconds = Math.max(0, Math.round(ap.last_seen_age_ms / 1000));
    if (seconds < 5)
        return "Last seen: just now";
    if (seconds < 60)
        return "Last seen: " + seconds + "s ago";
    const minutes = Math.round(seconds / 60);
    return minutes < 60 ? "Last seen: " + minutes + "m ago" : "Last seen: " + Math.round(minutes / 60) + "h ago";
}

function formatMbps(value) {
    if (!hasNumber(value))
        return "—";
    const rounded = Math.round(value * 10) / 10;
    return (Math.abs(rounded - Math.round(rounded)) < 0.01 ? Math.round(rounded) : rounded) + " Mbps";
}

function enterpriseTarget(ap, identity) {
    const target = JSON.parse(JSON.stringify(ap));
    target.enterprise = { eap: ["peap"], identity: identity, phase2_auth: "mschapv2" };
    return target;
}

function connectFailureMessage(result, fallbackText) {
    const reasonLabels = { "secret-required": "Password required", "authorization-required": "Authorization required", "unsupported-auth": "Unsupported Wi-Fi authentication", "validation-error": "Invalid Wi-Fi target", timeout: "Connection timed out", "activation-failed": "Connection activation failed", unknown: "Connect failed" };
    const label = reasonLabels[result.reason || "unknown"] || "Connect failed";
    return label + ": " + (result.message || fallbackText || "unknown error");
}
