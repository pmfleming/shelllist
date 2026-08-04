.pragma library

const icons = ({
    captivePortal: "󱚵", // md-wifi-alert
    open: "󰌿",         // md-lock-open
    enhancedOpen: "󱦚", // md-shield-lock-open
    legacy: "󰣮",       // md-lock-alert
    personal: "󰌾",     // md-lock
    enterprise: "󰢏",   // md-shield-account
    unknown: "󰣯"       // md-lock-question
});

function inferredSecurityClass(network) {
    const value = network || ({});
    const declared = String(value.security_class || "").toLowerCase();
    if (["open", "enhanced-open", "legacy", "personal", "enterprise", "unknown"].indexOf(declared) >= 0)
        return declared;

    const security = String(value.security || "").toUpperCase();
    const keyManagement = (Number(value.wpa_flags) || 0) | (Number(value.rsn_flags) || 0);
    if ((keyManagement & (0x0200 | 0x2000)) !== 0 || security.indexOf("ENTERPRISE") >= 0)
        return "enterprise";
    if ((keyManagement & (0x0800 | 0x1000)) !== 0 || security.indexOf("OWE") >= 0)
        return "enhanced-open";
    if (security === "WEP")
        return "legacy";
    if (security.indexOf("WPA") >= 0 || (keyManagement & (0x0100 | 0x0400)) !== 0)
        return "personal";
    if ((security === "--" || security === "OPEN" || security === "")
            && (Number(value.flags) || 0) === 0 && keyManagement === 0)
        return "open";
    return "unknown";
}

function networkType(network, captivePortal) {
    return captivePortal ? "captive-portal" : inferredSecurityClass(network);
}

function forNetwork(network, captivePortal) {
    const type = networkType(network, captivePortal);
    if (type === "captive-portal")
        return icons.captivePortal;
    if (type === "enhanced-open")
        return icons.enhancedOpen;
    return icons[type] || icons.unknown;
}
