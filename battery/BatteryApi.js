.pragma library

var protocol = "bar-api";
var version = 1;

var methods = {
    snapshot: "bar.snapshot",
    setThresholds: "battery.setThresholds",
    setProtection: "battery.setProtection",
    chargeOnce: "battery.chargeOnce",
    setAlertPolicy: "battery.setAlertPolicy"
};

var streams = {
    battery: "battery.changed"
};

var subscribedStreams = [streams.battery];
