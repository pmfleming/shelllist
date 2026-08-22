.pragma library

var protocol = "nm-api";
var version = 1;

var methods = {
    wifi_setEnabled: "wifi.setEnabled",
    network_inventory: "network.inventory",
    network_status: "network.status",
    network_activateProfile: "network.activateProfile",
    network_deactivate: "network.deactivate",
    network_statistics_watch: "network.statistics.watch",
    hotspot_capabilities: "hotspot.capabilities",
    hotspot_status: "hotspot.status",
    hotspot_start: "hotspot.start",
    hotspot_stop: "hotspot.stop",
    vpn_list: "vpn.list",
    vpn_status: "vpn.status",
    vpn_connect: "vpn.connect",
    vpn_disconnect: "vpn.disconnect",
    wifi_qr_parse: "wifi.qr.parse",
    wifi_qr_connect: "wifi.qr.connect",
    wifi_networks: "wifi.networks",
    wifi_band_status: "wifi.band.status",
    wifi_band_set: "wifi.band.set",
    wifi_scan: "wifi.scan",
    wifi_connectTarget: "wifi.connectTarget",
    wifi_disconnect: "wifi.disconnect",
    wifi_profile_operation: "wifi.profile.operation",
    wifi_secret_provide: "wifi.secret.provide"
};

var streams = {
    wifi_status: "wifi.status",
    network_connectivity: "network.connectivity",
    network_inventory: "network.inventory",
    network_statistics: "network.statistics",
    hotspot: "hotspot",
    vpn: "vpn",
    network_health: "network.health",
    wifi_networks: "wifi.networks",
    wifi_scan: "wifi.scan",
    wifi_connect: "wifi.connect",
    wifi_band: "wifi.band",
    wifi_secret: "wifi.secret"
};

var subscribedStreams = [
    streams.wifi_status,
    streams.network_connectivity,
    streams.network_health,
    streams.wifi_networks,
    streams.wifi_scan,
    streams.wifi_connect,
    streams.wifi_band,
    streams.wifi_secret
];

// Streams tied to an operation the shell starts on demand. Subscribing to
// them by default would make the daemon compute payloads nobody is reading.
var onDemandStreams = [
    streams.network_inventory,
    streams.network_statistics,
    streams.hotspot,
    streams.vpn
];
