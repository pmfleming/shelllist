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
function activeAccessPoint(status) { return status ? status.access_point || (status.network || null) : null; }
function subnetLabel(ip4) { return ip4 && ip4.prefix !== null && ip4.prefix !== undefined ? "/" + ip4.prefix : "—"; }
function dnsLabel(ip4) { return ip4 && ip4.dns && ip4.dns.length > 0 ? ip4.dns.join(", ") : "—"; }
function hasNumber(value) { return value !== null && value !== undefined && !isNaN(value); }
function privacyFor(profile) { return profile && profile.privacy ? profile.privacy : ({}); }
function isOpenNetwork(ap) { return !!(ap && ap.security === "--" && hasNetworkIdentity(ap)); }
function canShareQr(ap) { return isOpenNetwork(ap); }

function escapeHtml(value) {
    return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function escapeRegExp(value) {
    return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function hotkeyStartIndex(label, key) {
    const match = new RegExp("(^|[ -])" + escapeRegExp(key)).exec(label);
    return match ? match.index + match[1].length : label.indexOf(key);
}

function nmApiArgs() { const args = ["nm-api"]; for (let i = 0; i < arguments.length; i++) args.push(arguments[i]); return args; }

function highlightHotkey(text, hotkey) {
    const labelText = String(text);
    const keyText = String(hotkey);
    if (keyText.length === 0)
        return escapeHtml(labelText);

    const index = hotkeyStartIndex(labelText.toLowerCase(), keyText.charAt(0).toLowerCase());
    if (index < 0)
        return escapeHtml(labelText);

    return escapeHtml(labelText.slice(0, index))
        + "<u><b>" + escapeHtml(labelText.charAt(index)) + "</b></u>"
        + escapeHtml(labelText.slice(index + 1));
}

function pick(source, key) { return key && source ? source[key] : source; }
function isApiEnvelope(response) { return response && response.protocol === "nm-api"; }
function apiPayload(response) {
    if (response.version !== 1)
        throw new Error("Unsupported nm-api protocol version " + response.version);
    return response.data || {};
}
function apiErrorMessage(response) {
    const error = response.error || {};
    return (error.code || "api-error") + ": " + (error.message || "nm-api request failed");
}
function apiErrorResult(response) {
    const error = response.error || {};
    return { status: "error", reason: error.code || "unknown", message: error.message || "nm-api request failed" };
}

function apiData(response, key) {
    if (!isApiEnvelope(response))
        return pick(response, key);
    const data = apiPayload(response);
    if (!response.ok)
        throw new Error(apiErrorMessage(response));
    return pick(data, key);
}

function apiResult(response, key) {
    if (!isApiEnvelope(response))
        return pick(response, key);
    const data = apiPayload(response);
    if (!response.ok)
        return key && data[key] ? data[key] : apiErrorResult(response);
    return pick(data, key);
}

function escapeWifiQr(value) {
    const text = String(value || "");
    let escaped = "";
    const special = "\\;,:\"";
    for (let i = 0; i < text.length; i++) {
        const char = text.charAt(i);
        escaped += special.indexOf(char) >= 0 ? "\\" + char : char;
    }
    return escaped;
}

function wifiQrPayload(ap) {
    if (!canShareQr(ap))
        return "";
    const hidden = ap.hidden ? ";H:true" : "";
    return "WIFI:T:nopass;S:" + escapeWifiQr(networkName(ap)) + hidden + ";;";
}

function sameNonEmpty(left, right) { return !!left && !!right && left === right; }
function accessPointIdentity(ap) { return hasNetworkIdentity(ap) ? (ap.ssid || "") + "\n" + (ap.security || "") : ""; }
function sameAccessPointIdentity(left, right) { return sameNonEmpty(accessPointIdentity(left), accessPointIdentity(right)); }

function sameAccessPoint(left, right) {
    if (!left || !right)
        return false;
    const leftPath = accessPointPath(left);
    const rightPath = accessPointPath(right);
    if (leftPath || rightPath)
        return sameNonEmpty(leftPath, rightPath);
    return sameNonEmpty(left.bssid, right.bssid) || sameAccessPointIdentity(left, right);
}

function accessPointMatches(ap, active) {
    if (!ap)
        return false;
    return active ? sameAccessPoint(ap, active) : ap.active;
}

function isActiveAccessPoint(ap, active) {
    if (accessPointMatches(ap, active))
        return true;
    const children = ap && ap.access_points ? ap.access_points : [];
    return children.some(function (child) { return accessPointMatches(child, active); });
}

function profileForAccessPoint(ap, active, activeStatus) {
    if (!ap)
        return null;
    if (ap.primary_profile)
        return ap.primary_profile;
    if (ap.profiles && ap.profiles.length > 0)
        return ap.profiles[0];
    return active && activeStatus && activeStatus.profile ? activeStatus.profile : null;
}

function selectedNetwork(networks, selectedIndex) {
    return networks.length === 0 ? null : networks[clampIndex(selectedIndex, networks.length)];
}

function selectedIndexAfterUpdate(previous, networks, selectedIndex, resetSelection, isActiveCallback) {
    if (resetSelection || !previous) {
        const activeIndex = networks.findIndex(isActiveCallback);
        return activeIndex >= 0 ? activeIndex : 0;
    }
    const nextIndex = networks.findIndex(function (ap) { return sameAccessPoint(previous, ap); });
    return nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, networks.length);
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

function relativeAgeLabel(seconds) {
    if (seconds < 5) return "just now";
    if (seconds < 60) return seconds + "s ago";
    const minutes = Math.round(seconds / 60);
    return minutes < 60 ? minutes + "m ago" : Math.round(minutes / 60) + "h ago";
}

function lastSeenLabel(ap) {
    if (!ap || ap.last_seen < 0)
        return "";
    if (!hasNumber(ap.last_seen_age_ms))
        return "Last seen: scan result available";
    const seconds = Math.max(0, Math.round(ap.last_seen_age_ms / 1000));
    return "Last seen: " + relativeAgeLabel(seconds);
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
    const reasonLabels = { "secret-required": "Password required", "authorization-required": "Authorization required", "unsupported-auth": "Unsupported Wi-Fi authentication", "validation-error": "Invalid Wi-Fi target", "not-found": "Wi-Fi network not found", timeout: "Connection timed out", "activation-failed": "Connection activation failed", unknown: "Connect failed" };
    const label = reasonLabels[result.reason || "unknown"] || "Connect failed";
    return label + ": " + (result.message || fallbackText || "unknown error");
}

function connectResultMessage(result, fallbackText) {
    if (result.status === "error")
        return connectFailureMessage(result, fallbackText);
    const connectivity = result.connectivity || {};
    if (result.suggest_open_portal)
        return result.message + "; opening captive portal…";
    if (connectivity.state === "full")
        return "Connected to " + result.ssid + " with full connectivity";
    if (connectivity.state)
        return "Connected to " + result.ssid + "; connectivity: " + connectivity.state;
    return result.message;
}
