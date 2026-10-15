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
    "wifi.setEnabled": {responseHandler: "power"},
    "wifi.band.set": {responseHandler: "band-set", execution: "operation"},
    "wifi.disconnect": {responseHandler: "disconnect"},
    "hotspot.start": {responseHandler: "hotspot-start", execution: "operation"},
    "hotspot.stop": {responseHandler: "hotspot-stop"},
    "vpn.connect": {responseHandler: "vpn-connect", execution: "operation"},
    "vpn.disconnect": {responseHandler: "vpn-disconnect"},
    "network.activateProfile": {responseHandler: "activate-profile", execution: "operation"},
    "network.deactivate": {responseHandler: "deactivate-connection"},
    "wifi.scan": {responseHandler: "scan-start", concurrency: "scan", execution: "operation"},
    "wifi.connectTarget": {responseHandler: "connect-start", concurrency: "connect", execution: "operation"},
    "wifi.qr.connect": {responseHandler: "connect-start", concurrency: "connect", execution: "operation"},
    "network.portalPrepare": {responseHandler: "portal", conflictDomain: "portal", concurrency: "portal"},
    "network.portalClaim": {responseHandler: "portal", conflictDomain: "portal", concurrency: "portal"},
    "network.portalComplete": {responseHandler: "portal", conflictDomain: "portal", concurrency: "portal"}
};
var profileReads = {details: "advanced-load", share: "share", "reveal-secret": "advanced-secret"};

function read(handler) {
    return {responseHandler: handler, conflictDomain: "none", concurrency: "read", sensitivity: "sensitive-read", execution: "read"};
}
function effect(overrides) {
    return Object.assign({responseHandler: "", conflictDomain: "wifi-link", concurrency: "exclusive", sensitivity: "effect", execution: "effect"}, overrides);
}
function classify(method, params) {
    if (method === "wifi.networks" && params.refresh_cache === true)
        // A stale-cache read can schedule a real background radio scan.
        return effect({responseHandler: "networks", conflictDomain: "wifi-scan", concurrency: "cache-refresh", execution: "operation"});
    if (Object.prototype.hasOwnProperty.call(reads, method))
        return read(reads[method]);
    if (method === "wifi.profile.operation") {
        if (Object.prototype.hasOwnProperty.call(profileReads, params.operation))
            return read(profileReads[params.operation]);
        return effect({responseHandler: params.operation === "update" ? "advanced-save" : "profile"});
    }
    if (method === "wifi.secret.provide")
        return effect({responseHandler: params.cancel ? "secret-cancel" : "secret-provide"});
    if (method === "network.statistics.watch")
        return Object.assign(read("statistics-watch"), {execution: "operation"});
    return effect(Object.prototype.hasOwnProperty.call(effects, method) ? effects[method] : {});
}
