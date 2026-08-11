.pragma library

var protocol = "nm-api";
var version = 1;

var methods = {
    wifi_setEnabled: "wifi.setEnabled",
    wifi_networks: "wifi.networks",
    wifi_scan: "wifi.scan",
    wifi_connectTarget: "wifi.connectTarget",
    wifi_disconnect: "wifi.disconnect",
    wifi_profile_operation: "wifi.profile.operation",
    wifi_secret_provide: "wifi.secret.provide"
};

var streams = {
    wifi_status: "wifi.status",
    network_connectivity: "network.connectivity",
    wifi_scan: "wifi.scan",
    wifi_connect: "wifi.connect",
    wifi_secret: "wifi.secret"
};

var subscribedStreams = [
    streams.wifi_status,
    streams.network_connectivity,
    streams.wifi_scan,
    streams.wifi_connect,
    streams.wifi_secret
];
