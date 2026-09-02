.pragma library
.import "../bar/BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var methods = {
    snapshot: Protocol.methods["bar.snapshot"],
    history: Protocol.methods["battery.history"],
    setThresholds: Protocol.methods["battery.setThresholds"],
    setProtection: Protocol.methods["battery.setProtection"],
    chargeOnce: Protocol.methods["battery.chargeOnce"],
    setChargingInhibited: Protocol.methods["battery.setChargingInhibited"],
    startCalibration: Protocol.methods["battery.startCalibration"],
    cancelCalibration: Protocol.methods["battery.cancelCalibration"],
    setAlertPolicy: Protocol.methods["battery.setAlertPolicy"],
    setPowerProfile: Protocol.methods["powerProfile.set"],
    setBatteryAware: Protocol.methods["powerProfile.setBatteryAware"],
    setPowerActionEnabled: Protocol.methods["powerProfile.setActionEnabled"],
    lock: Protocol.methods["powerSleep.lock"],
    suspend: Protocol.methods["powerSleep.suspend"],
    hibernate: Protocol.methods["powerSleep.hibernate"]
};

var streams = {
    battery: Protocol.streams["battery.changed"],
    powerProfile: Protocol.streams["power-profile.changed"],
    powerSleep: Protocol.streams["power-sleep.changed"]
};

var subscribedStreams = [streams.battery, streams.powerProfile, streams.powerSleep];
