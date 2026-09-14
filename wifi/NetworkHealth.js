.pragma library

// Presentation of daemon-classified network.health events. NetworkManager
// transition/reason policy belongs to nm-daemon; the UI only decides where and
// when to display its recommendation.

var SUBJECT_LABEL = {
    device: "Network device",
    connection: "Connection",
    vpn: "VPN"
};

function health(event) {
    return (event && event.health) || {};
}

function reason(event) {
    return health(event).reason || {};
}

// Do not maintain a second terminal-state/reason classifier here. This also
// permits new daemon-classified failure states without a frontend release.
// Missing advice stays quiet rather than guessing from legacy raw state.
function isFailure(event) {
    return health(event).notification_recommended === true;
}

function notificationKey(event) {
    const detail = health(event);
    const connection = detail.device_path || detail.active_connection_path || detail.profile_path || detail.uuid || identity(event);
    return connection + "|" + (detail.state_name || "unknown") + "|" + (reason(event).name || "unknown");
}

function isDuplicateNotification(event, lastKey, lastAtMs, nowMs, windowMs) {
    return notificationKey(event) === lastKey && nowMs - lastAtMs < windowMs;
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
    if (typeof detail.message === "string" && detail.message.length > 0)
        return detail.message;
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
    return "subject=" + (detail.subject || "unknown") + " state=" + (detail.state_name || "unknown") + " reason=" + (reason(event).name || "unknown") + " category=" + (reason(event).category || "unknown") + " unexpected=" + !!detail.unexpected + " kind=" + (detail.transition_kind || "legacy") + " notify=" + (detail.notification_recommended === true) + " severity=" + (detail.severity || "unknown") + " id=" + (detail.id || "") + " iface=" + (detail.device_iface || "");
}
