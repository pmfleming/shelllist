.pragma library
.import "NmApi.js" as NmApi

function clampIndex(index, length) { return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1)); }
function networkName(ap) { return ap && ap.ssid ? ap.ssid : "<hidden>"; }
function securityLabel(security) { return security === "--" ? "Open" : (security || "Unknown"); }
function hasNetworkIdentity(ap) { return !!(ap && ((ap.ssid_bytes && ap.ssid_bytes.length > 0) || (ap.ssid && ap.ssid.length > 0))); }
function connectPromptKind(ap) { return ap && ap.connect_prompt ? (ap.connect_prompt.kind || "none") : "none"; }
function canConnect(ap) { return !!(ap && ap.capabilities && ap.capabilities.can_connect); }
function needsPassword(ap) { return !!(ap && hasNetworkIdentity(ap) && connectPromptKind(ap) === "password"); }
function needsCredentials(ap) { return !!(ap && hasNetworkIdentity(ap) && connectPromptKind(ap) === "enterprise"); }
function canStartConnection(ap) { return canConnect(ap) || needsPassword(ap) || needsCredentials(ap); }
function accessPointPath(ap) { return ap ? (ap.path || "") : ""; }
function subnetLabel(ip4) { return ip4 && ip4.prefix !== null && ip4.prefix !== undefined ? "/" + ip4.prefix : "—"; }
function dnsLabel(ip4) { return ip4 && ip4.dns && ip4.dns.length > 0 ? ip4.dns.join(", ") : "—"; }
function hasNumber(value) { return value !== null && value !== undefined && !isNaN(value); }
function privacyFor(profile) { return profile && profile.privacy ? profile.privacy : ({}); }
function shareHint(ap) { return ap && ap.share ? ap.share : ({}); }
function canShareQr(ap) { const share = shareHint(ap); return !!share.shareable && !!share.qr_payload; }
function isWrongPasswordReason(reason) { return reason === "wrong-password"; }
function isSecretFailureReason(reason) { return isWrongPasswordReason(reason) || reason === "password-unavailable" || reason === "secret-required"; }
function connectFailureRetryMs(reason) { return isWrongPasswordReason(reason) ? 10000 : 0; }
function secretKey(ap) { return (ap && (ap.ssid || "")) + "\n" + (ap && (ap.security || "")); }
function connectAttemptKey(ap) { return secretKey(ap) + "\n" + (ap && (ap.bssid || "")); }
function portalNetworkIdentity(ap, result) {
    if (ap && ap.key)
        return ap.key;
    const profile = ap && (ap.primary_profile || (ap.profiles && ap.profiles.length > 0 ? ap.profiles[0] : null));
    if (profile && profile.path)
        return profile.path;
    const ssid = result && result.ssid ? result.ssid : networkName(ap);
    return ssid + "|" + securityLabel(ap && ap.security);
}
function confirmedPortalResult(result) {
    const connectivity = result && result.connectivity ? result.connectivity : null;
    return !!(result && result.status !== "error" && result.suggest_open_portal && connectivity && connectivity.captive_portal);
}
function passwordFingerprint(password) {
    if (password === undefined || password === null)
        return "saved";
    let hash = 0;
    for (let i = 0; i < password.length; i++)
        hash = ((hash << 5) - hash + password.charCodeAt(i)) | 0;
    return "pw:" + password.length + ":" + hash;
}

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
function isApiEnvelope(response) { return response && response.protocol === NmApi.protocol; }
function apiPayload(response) {
    if (!isApiEnvelope(response))
        throw new Error("Expected nm-api response envelope");
    if (response.version !== NmApi.version)
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
    const data = apiPayload(response);
    if (!response.ok)
        throw new Error(apiErrorMessage(response));
    return pick(data, key);
}

function apiResult(response, key) {
    const data = apiPayload(response);
    if (!response.ok)
        return key && data[key] ? data[key] : apiErrorResult(response);
    return pick(data, key);
}

function requireApiEvent(event) {
    if (!isApiEnvelope(event) || event.version !== NmApi.version || !event.stream || !event.event)
        throw new Error("Expected nm-api v1 event envelope");
    return event;
}

function scanEventStatus(event, fallback) {
    const messages = { snapshot: event.networks_found + (event.scanning ? " networks found; scanning…" : " networks available"), complete: event.networks_found + (event.timed_out ? " networks available; scan timed out" : " networks available") };
    return messages[event.event] || event.message || fallback;
}

function isTerminalEvent(event) { return event.event === "complete" || event.event === "failed" || event.event === "cancelled"; }
function requestMatches(event, requestId) { return !!event.request_id && event.request_id === requestId; }
function connectEventResult(event) { return event.result || ({ status: "error", reason: event.reason || "unknown", message: event.message || "Connection failed" }); }
function connectEventState(event) { return event.event === "succeeded" ? "succeeded" : (event.event === "failed" || event.event === "cancelled" ? "failed" : "progress"); }

function wifiQrPayload(ap) {
    if (!canShareQr(ap))
        return "";
    return shareHint(ap).qr_payload || "";
}

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
    return { path: result.path || "", available: available, payload: available ? result.qr_payload : "", message: available ? "Wi-Fi QR payload is ready." : (result.reason || fallbackMessage) };
}

function sameNonEmpty(left, right) { return !!left && !!right && left === right; }
function accessPointIdentity(ap) { return hasNetworkIdentity(ap) ? (ap.ssid || "") + "\n" + (ap.security || "") : ""; }
function sameAccessPointIdentity(left, right) { return sameNonEmpty(accessPointIdentity(left), accessPointIdentity(right)); }

function sameAccessPoint(left, right) {
    if (!left || !right)
        return false;
    if (sameNonEmpty(left.key, right.key))
        return true;
    const leftPath = accessPointPath(left);
    const rightPath = accessPointPath(right);
    if (leftPath || rightPath)
        return sameNonEmpty(leftPath, rightPath);
    return sameNonEmpty(left.bssid, right.bssid) || sameAccessPointIdentity(left, right);
}

function profileForAccessPoint(ap) {
    if (!ap)
        return null;
    return ap.primary_profile || (ap.profiles && ap.profiles.length > 0 ? ap.profiles[0] : null);
}

function visibleNetworks(networks, filterText) {
    const query = (filterText || "").toLowerCase();
    return networks.filter(function (ap) {
        return !query || (ap.ssid || "").toLowerCase().indexOf(query) !== -1;
    }).sort(function (left, right) {
        const leftActive = !!left.active;
        const rightActive = !!right.active;
        if (leftActive !== rightActive)
            return leftActive ? -1 : 1;
        const strengthDelta = (right.strength || 0) - (left.strength || 0);
        return strengthDelta !== 0 ? strengthDelta : networkName(left).localeCompare(networkName(right));
    });
}

function selectedNetwork(networks, selectedIndex) {
    return networks.length === 0 ? null : networks[clampIndex(selectedIndex, networks.length)];
}

function selectedIndexAfterUpdate(previous, networks, selectedIndex, resetSelection) {
    if (resetSelection || !previous) {
        const activeIndex = networks.findIndex(function (network) { return !!network.active; });
        return activeIndex >= 0 ? activeIndex : 0;
    }
    const nextIndex = networks.findIndex(function (ap) { return sameAccessPoint(previous, ap); });
    return nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, networks.length);
}

function bandLabel(ap) {
    if (ap && ap.band)
        return ap.band;
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    return frequency >= 5925 ? "6 GHz" : frequency >= 4900 ? "5 GHz" : frequency > 0 ? "2.4 GHz" : "Unknown";
}

function frequencyLabel(ap) {
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    if (frequency <= 0)
        return "Unknown";
    return bandLabel(ap) + " (" + frequency + " MHz)";
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

function activeConnectivity(controller) {
    if (!controller)
        return null;
    return controller.networkConnectivity || (controller.activeStatus && controller.activeStatus.connectivity) || null;
}

function connectivityRequiresSignIn(connectivity) {
    return !!(connectivity && (connectivity.captive_portal || connectivity.state === "portal"));
}

function connectionStateLabel(controller, ap) {
    if (!controller.isActive(ap) || !controller.activeStatus)
        return "";
    const connectivity = activeConnectivity(controller);
    if (connectivityRequiresSignIn(connectivity))
        return "Sign in required";
    if (!connectivity || connectivity.state === "unknown")
        return "Checking internet access…";
    if (connectivity.state === "none")
        return "No internet access";
    if (connectivity.state === "limited")
        return "Limited connectivity";
    return connectivity.full || connectivity.state === "full" ? "Connected" : "Checking internet access…";
}

function lastSeenLabel(ap) {
    if (!ap || ap.last_seen < 0)
        return "";
    if (!hasNumber(ap.last_seen_age_ms))
        return "Last seen: scan result available";
    const seconds = Math.max(0, Math.round(ap.last_seen_age_ms / 1000));
    return "Last seen: " + relativeAgeLabel(seconds);
}

function connectionDetailRows(controller, ap, accentColor) {
    const status = detailConnectionStatus(controller);
    const ip4 = status && status.ip4 ? status.ip4 : null;
    const present = function (value) { return status ? value : "—"; };
    const ip4Value = function (field) { return ip4 && ip4[field] ? ip4[field] : "—"; };
    return [
        { label: "Signal strength", value: (ap.strength || 0) + "%", valueColor: accentColor, valueBold: true },
        { label: "IP address", value: ip4Value("address") },
        { label: "Frequency", value: frequencyLabel(ap) },
        { label: "Gateway", value: ip4Value("gateway") },
        { label: "Band", value: bandLabel(ap) },
        { label: "Security", value: securityLabel(ap.security) },
        { label: "Subnet", value: present(subnetLabel(ip4)) },
        { label: "Network usage", value: present(networkUsageLabel(status)) },
        { label: "DNS", value: present(dnsLabel(ip4)), valueWidth: 220 }
    ];
}

function networkDetailRows(controller, ap) {
    const status = detailConnectionStatus(controller);
    const wireless = status && status.wireless ? status.wireless : null;
    const bitrate = function (field) { return status && wireless ? formatMbps(wireless[field]) : "—"; };
    const directional = !!(wireless && (hasNumber(wireless.tx_bitrate_mbps) || hasNumber(wireless.rx_bitrate_mbps)));
    return [
        { label: "Type", value: wifiType(ap) },
        { label: directional ? "Transmit link speed" : "Link speed", value: bitrate(directional ? "tx_bitrate_mbps" : "bitrate_mbps") },
        { label: "BSSID", value: ap && ap.bssid ? ap.bssid : "—" },
        { label: "Receive link speed", value: bitrate("rx_bitrate_mbps") },
        { label: "Device MAC", value: wireless && wireless.mac_address ? wireless.mac_address : "—" }
    ];
}

function formatMbps(value) {
    if (!hasNumber(value))
        return "—";
    const rounded = Math.round(value * 10) / 10;
    return (Math.abs(rounded - Math.round(rounded)) < 0.01 ? Math.round(rounded) : rounded) + " Mbps";
}

function copyTruthy(target, source, keys) {
    keys.forEach(function (key) {
        if (source[key])
            target[key] = source[key];
    });
}

function connectTarget(ap) {
    const target = { ssid: ap.ssid || "", ssid_bytes: ap.ssid_bytes || [], path: ap.path || "", bssid: ap.bssid || "", device_iface: ap.device_iface || "", device_path: ap.device_path || "", security: ap.security || null };
    copyTruthy(target, ap, ["key_mgmt", "enterprise", "profile"]);
    if (ap.hidden)
        target.hidden = true;
    return target;
}

function enterpriseTarget(ap, identity) {
    const target = connectTarget(ap);
    const defaults = ap && ap.connect_prompt && ap.connect_prompt.enterprise_defaults ? ap.connect_prompt.enterprise_defaults : ({ eap: ["peap"], phase2_auth: "mschapv2" });
    target.enterprise = JSON.parse(JSON.stringify(defaults));
    target.enterprise.identity = identity;
    return target;
}

function connectFailureMessage(result, fallbackText) {
    const reasonLabels = { "secret-required": "Password required", "wrong-password": "Wrong password", "password-unavailable": "Password unavailable", "authorization-required": "Authorization required", "unsupported-auth": "Unsupported Wi-Fi authentication", "validation-error": "Invalid Wi-Fi target", "not-found": "Wi-Fi network not found", timeout: "AP unreachable or weak signal", "dhcp-failed": "Connected to Wi-Fi but no IP", "activation-failed": "Connection activation failed", unknown: "Connect failed" };
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
