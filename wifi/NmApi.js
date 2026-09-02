.pragma library
.import "NmProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var methods = {
    wifi_status: Protocol.methods["wifi.status"],
    wifi_setEnabled: Protocol.methods["wifi.setEnabled"],
    network_inventory: Protocol.methods["network.inventory"],
    network_status: Protocol.methods["network.status"],
    network_activateProfile: Protocol.methods["network.activateProfile"],
    network_deactivate: Protocol.methods["network.deactivate"],
    network_statistics_watch: Protocol.methods["network.statistics.watch"],
    hotspot_capabilities: Protocol.methods["hotspot.capabilities"],
    hotspot_status: Protocol.methods["hotspot.status"],
    hotspot_start: Protocol.methods["hotspot.start"],
    hotspot_stop: Protocol.methods["hotspot.stop"],
    vpn_list: Protocol.methods["vpn.list"],
    vpn_status: Protocol.methods["vpn.status"],
    vpn_connect: Protocol.methods["vpn.connect"],
    vpn_disconnect: Protocol.methods["vpn.disconnect"],
    wifi_qr_parse: Protocol.methods["wifi.qr.parse"],
    wifi_qr_connect: Protocol.methods["wifi.qr.connect"],
    wifi_networks: Protocol.methods["wifi.networks"],
    wifi_band_status: Protocol.methods["wifi.band.status"],
    wifi_band_set: Protocol.methods["wifi.band.set"],
    wifi_scan: Protocol.methods["wifi.scan"],
    wifi_connectTarget: Protocol.methods["wifi.connectTarget"],
    wifi_disconnect: Protocol.methods["wifi.disconnect"],
    wifi_profile_operation: Protocol.methods["wifi.profile.operation"],
    wifi_secret_provide: Protocol.methods["wifi.secret.provide"]
};

var streams = {
    wifi_status: Protocol.streams["wifi.status"],
    network_connectivity: Protocol.streams["network.connectivity"],
    network_inventory: Protocol.streams["network.inventory"],
    network_statistics: Protocol.streams["network.statistics"],
    hotspot: Protocol.streams["hotspot"],
    vpn: Protocol.streams["vpn"],
    network_health: Protocol.streams["network.health"],
    wifi_networks: Protocol.streams["wifi.networks"],
    wifi_scan: Protocol.streams["wifi.scan"],
    wifi_connect: Protocol.streams["wifi.connect"],
    wifi_band: Protocol.streams["wifi.band"],
    wifi_secret: Protocol.streams["wifi.secret"]
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
