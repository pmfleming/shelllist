.pragma library

function networkName(network) { return network && network.ssid ? network.ssid : "<hidden>"; }
function securityLabel(security) { return security === "--" ? "Open" : (security || "Unknown"); }
function subnetLabel(ip4) { return ip4 && ip4.prefix !== null && ip4.prefix !== undefined ? "/" + ip4.prefix : "—"; }
function dnsLabel(ip4) { return ip4 && ip4.dns && ip4.dns.length > 0 ? ip4.dns.join(", ") : "—"; }
function hasNumber(value) { return value !== null && value !== undefined && !isNaN(value); }
function valueOr(source, key, fallback) { return source && source[key] !== undefined && source[key] !== null ? source[key] : fallback; }
function privacyFor(profile) { return profile && profile.privacy ? profile.privacy : ({}); }

function bandLabel(ap) {
    if (ap && ap.band)
        return ap.band;
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    return frequency >= 5925 ? "6 GHz" : frequency >= 4900 ? "5 GHz" : frequency > 0 ? "2.4 GHz" : "Unknown";
}
function frequencyLabel(ap) {
    const frequency = ap && ap.frequency ? ap.frequency : 0;
    return frequency <= 0 ? "Unknown" : bandLabel(ap) + " (" + frequency + " MHz)";
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
    return controller.connection.connectivity || (controller.activeStatus && controller.activeStatus.connectivity) || null;
}
function connectivityRequiresSignIn(connectivity) {
    return !!(connectivity && (connectivity.captive_portal || connectivity.state === "portal"));
}
function connectionStateLabel(controller, ap) {
    if (!controller.isActive(ap) || !controller.activeStatus)
        return "";
    const connectivity = activeConnectivity(controller);
    if (connectivityRequiresSignIn(connectivity)) return "Sign in required";
    if (!connectivity || connectivity.state === "unknown") return "Checking internet access…";
    if (connectivity.state === "none") return "No internet access";
    if (connectivity.state === "limited") return "Limited connectivity";
    return connectivity.full || connectivity.state === "full" ? "Connected" : "Checking internet access…";
}
function lastSeenLabel(ap) {
    if (!ap || ap.last_seen < 0)
        return "";
    if (!hasNumber(ap.last_seen_age_ms))
        return "Last seen: scan result available";
    return "Last seen: " + relativeAgeLabel(Math.max(0, Math.round(ap.last_seen_age_ms / 1000)));
}
function statusValue(status, value) { return status ? value : "—"; }
function formatMbps(value) {
    if (!hasNumber(value)) return "—";
    const rounded = Math.round(value * 10) / 10;
    return (Math.abs(rounded - Math.round(rounded)) < 0.01 ? Math.round(rounded) : rounded) + " Mbps";
}
function wirelessBitrate(status, wireless, field) { return status && wireless ? formatMbps(wireless[field]) : "—"; }
function hasDirectionalBitrate(wireless) { return !!wireless && (hasNumber(wireless.tx_bitrate_mbps) || hasNumber(wireless.rx_bitrate_mbps)); }
function connectionDetailRows(controller, ap, accentColor) {
    const status = detailConnectionStatus(controller);
    const ip4 = valueOr(status, "ip4", null);
    return [
        { label: "Signal strength", value: valueOr(ap, "strength", 0) + "%", valueColor: accentColor, valueBold: true },
        { label: "IP address", value: valueOr(ip4, "address", "—") },
        { label: "Frequency", value: frequencyLabel(ap) },
        { label: "Gateway", value: valueOr(ip4, "gateway", "—") },
        { label: "Band", value: bandLabel(ap) },
        { label: "Security", value: securityLabel(valueOr(ap, "security", "")) },
        { label: "Subnet", value: statusValue(status, subnetLabel(ip4)) },
        { label: "Network usage", value: statusValue(status, networkUsageLabel(status)) },
        { label: "DNS", value: statusValue(status, dnsLabel(ip4)), valueWidth: 220 }
    ];
}
function networkDetailRows(controller, ap) {
    const status = detailConnectionStatus(controller);
    const wireless = valueOr(status, "wireless", null);
    const directional = hasDirectionalBitrate(wireless);
    return [
        { label: "Type", value: wifiType(ap) },
        { label: directional ? "Transmit link speed" : "Link speed", value: wirelessBitrate(status, wireless, directional ? "tx_bitrate_mbps" : "bitrate_mbps") },
        { label: "BSSID", value: valueOr(ap, "bssid", "—") },
        { label: "Receive link speed", value: wirelessBitrate(status, wireless, "rx_bitrate_mbps") },
        { label: "Device MAC", value: valueOr(wireless, "mac_address", "—") }
    ];
}
