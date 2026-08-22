.pragma library

// Presentation rules for the daemon's network.health stream. The daemon
// deliberately emits no notifications, so the decision about what a transition
// means to the user lives here.

var SUBJECT_LABEL = {
    device: "Network device",
    connection: "Connection",
    vpn: "VPN"
};

// Reason categories that describe a user's own action or an ordinary step.
var QUIET_CATEGORIES = ["none", "user-requested", "lifecycle"];

function health(event) { return (event && event.health) || {}; }

function reason(event) { return health(event).reason || {}; }

function isQuiet(event) {
    const detail = health(event);
    if (detail.user_requested)
        return true;
    return QUIET_CATEGORIES.indexOf(reason(event).category || "unknown") >= 0;
}

// Only a genuine failure is worth interrupting the user with.
function isFailure(event) {
    const detail = health(event);
    if (!detail.unexpected || isQuiet(event))
        return false;
    return detail.state_name === "failed" || detail.state_name === "deactivated"
        || detail.state_name === "disconnected" || detail.state_name === "unavailable";
}

function identity(event) {
    const detail = health(event);
    return detail.id || detail.device_iface || detail.connection_type || "network";
}

var REASON_MESSAGE = {
    "no-secrets": "needs a password",
    "supplicant-timeout": "timed out authenticating",
    "supplicant-failed": "could not authenticate",
    "supplicant-disconnect": "was disconnected by the access point",
    "login-failed": "rejected the sign-in",
    "dhcp-failed": "could not get an address",
    "dhcp-error": "could not get an address",
    "ip-config-unavailable": "could not get an address",
    "ip-config-expired": "lost its address lease",
    "ip-address-duplicate": "found a duplicate address",
    "ssid-not-found": "is out of range",
    "carrier": "lost its cable",
    "firmware-missing": "is missing firmware",
    "modem-not-found": "has no modem",
    "dependency-failed": "lost the connection it depends on",
    "secondary-connection-failed": "could not start its secondary connection",
    "connect-timeout": "timed out connecting",
    "service-start-failed": "could not start its service",
    "service-stopped": "had its service stop"
};

function message(event) {
    const detail = health(event);
    const known = REASON_MESSAGE[reason(event).name];
    if (known)
        return identity(event) + " " + known + ".";
    const label = SUBJECT_LABEL[detail.subject] || "Network";
    return label + " " + identity(event) + " is " + (detail.state_name || "in an unknown state") + ".";
}

// A compact line for logs; never includes a secret because health events do not
// carry one.
function logLine(event) {
    const detail = health(event);
    return "subject=" + (detail.subject || "unknown")
        + " state=" + (detail.state_name || "unknown")
        + " reason=" + (reason(event).name || "unknown")
        + " category=" + (reason(event).category || "unknown")
        + " unexpected=" + !!detail.unexpected
        + " id=" + (detail.id || "")
        + " iface=" + (detail.device_iface || "");
}
