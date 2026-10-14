.pragma library

// UI conflict policy is explicit and independent of request-ID spelling.
// Store only method/classification, never parameters, credentials or QR payloads.
var reads = {
    "wifi.status": "status-recovery",
    "wifi.networks": "networks",
    "wifi.band.status": "band-status",
    "wifi.qr.parse": "qr-parse",
    "wifi.qr.render": "share",
    "hotspot.capabilities": "hotspot-capabilities",
    "hotspot.status": "hotspot-status",
    "vpn.list": "vpn-list",
    "vpn.status": "vpn-status",
    "network.inventory": "inventory",
    "network.status": "network-status",
    "operation.status": "connection-status"
};
var effects = {
    "wifi.setEnabled": "power",
    "wifi.band.set": "band-set",
    "wifi.disconnect": "disconnect",
    "hotspot.start": "hotspot-start",
    "hotspot.stop": "hotspot-stop",
    "vpn.connect": "vpn-connect",
    "vpn.disconnect": "vpn-disconnect",
    "network.activateProfile": "activate-profile",
    "network.deactivate": "deactivate-connection"
};
function classify(method, params) {
    var info = {responseHandler: "", conflictDomain: "wifi-link", concurrency: "exclusive", sensitivity: "effect", execution: "effect"};
    function read(handler) {
        info.responseHandler = handler;
        info.conflictDomain = "none";
        info.concurrency = "read";
        info.sensitivity = "sensitive-read";
        info.execution = "read";
    }
    if (Object.prototype.hasOwnProperty.call(reads, method)) {
        read(reads[method]);
        if (method === "wifi.networks" && params.refresh_cache === true) {
            // A stale-cache read can schedule a real background radio scan.
            info.conflictDomain = "wifi-scan";
            info.concurrency = "cache-refresh";
            info.sensitivity = "effect";
            info.execution = "operation";
        }
    } else if (Object.prototype.hasOwnProperty.call(effects, method)) {
        info.responseHandler = effects[method];
        if (["wifi.band.set", "hotspot.start", "vpn.connect", "network.activateProfile"].includes(method))
            info.execution = "operation";
    } else if (method === "wifi.profile.operation") {
        const handlers = {details: "advanced-load", share: "share", "reveal-secret": "advanced-secret"};
        if (Object.prototype.hasOwnProperty.call(handlers, params.operation))
            read(handlers[params.operation]);
        else
            info.responseHandler = params.operation === "update" ? "advanced-save" : "profile";
    } else if (method === "wifi.secret.provide") {
        info.responseHandler = params.cancel ? "secret-cancel" : "secret-provide";
    } else if (method === "wifi.scan") {
        info.responseHandler = "scan-start";
        info.concurrency = "scan";
        info.execution = "operation";
    } else if (["wifi.connectTarget", "wifi.qr.connect"].includes(method)) {
        info.responseHandler = "connect-start";
        info.concurrency = "connect";
        info.execution = "operation";
    } else if (method === "network.statistics.watch") {
        read("statistics-watch");
        info.execution = "operation";
    } else if (["network.portalPrepare", "network.portalClaim", "network.portalComplete"].includes(method)) {
        info.responseHandler = "portal";
        info.conflictDomain = "portal";
        info.concurrency = "portal";
    }
    return info;
}
