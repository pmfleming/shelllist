.pragma library

var protocol = "bar-api";
var version = 1;

var methods = {
    snapshot: "bar.snapshot",
    setThresholds: "battery.setThresholds",
    setProtection: "battery.setProtection",
    chargeOnce: "battery.chargeOnce",
    setChargingInhibited: "battery.setChargingInhibited",
    startCalibration: "battery.startCalibration",
    cancelCalibration: "battery.cancelCalibration",
    setAlertPolicy: "battery.setAlertPolicy",
    setPowerProfile: "powerProfile.set",
    setBatteryAware: "powerProfile.setBatteryAware",
    setPowerActionEnabled: "powerProfile.setActionEnabled"
};

var streams = {
    battery: "battery.changed",
    powerProfile: "power-profile.changed"
};

var subscribedStreams = [streams.battery, streams.powerProfile];
