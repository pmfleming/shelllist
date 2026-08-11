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

function declaredClass(value) { return String(value.security_class || "").toLowerCase(); }
function securityText(value) { return String(value.security || "").toUpperCase(); }
function securityFlags(value) { return (Number(value.wpa_flags) || 0) | (Number(value.rsn_flags) || 0); }
function hasFlag(flags, mask) { return (flags & mask) !== 0; }
function isEnterprise(security, flags) { return hasFlag(flags, 0x0200 | 0x2000) || security.includes("ENTERPRISE"); }
function isEnhancedOpen(security, flags) { return hasFlag(flags, 0x0800 | 0x1000) || security.includes("OWE"); }
function isPersonal(security, flags) { return security.includes("WPA") || hasFlag(flags, 0x0100 | 0x0400); }
function isOpen(value, security, flags) {
    return ["--", "OPEN", ""].includes(security) && !Number(value.flags) && flags === 0;
}

function inferredSecurityClass(network) {
    const value = network ? network : ({});
    const declared = declaredClass(value);
    if (["open", "enhanced-open", "legacy", "personal", "enterprise", "unknown"].includes(declared))
        return declared;
    const security = securityText(value);
    const flags = securityFlags(value);
    if (isEnterprise(security, flags)) return "enterprise";
    if (isEnhancedOpen(security, flags)) return "enhanced-open";
    if (security === "WEP") return "legacy";
    if (isPersonal(security, flags)) return "personal";
    return isOpen(value, security, flags) ? "open" : "unknown";
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
