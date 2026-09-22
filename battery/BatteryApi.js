.pragma library
.import "../Bar/BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

// bar-api v1 wire names are stable; frontend terminology uses Suspend.
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
    resumeAutomaticProfiles: Protocol.methods["powerProfile.resumeAutomatic"],
    setBatteryAware: Protocol.methods["powerProfile.setBatteryAware"],
    setPowerActionEnabled: Protocol.methods["powerProfile.setActionEnabled"],
    lock: Protocol.methods["powerSleep.lock"],
    suspend: Protocol.methods["powerSleep.suspend"],
    hibernate: Protocol.methods["powerSleep.hibernate"],
    setKeepAwake: Protocol.methods["powerSleep.setKeepAwake"],
    setSuspendPolicy: Protocol.methods["powerSleep.setPolicy"],
    cancelCritical: Protocol.methods["powerSleep.cancelCritical"],
    setCriticalPolicy: Protocol.methods["powerSleep.setCriticalPolicy"]
};

var streams = {
    battery: Protocol.streams["battery.changed"],
    powerProfile: Protocol.streams["power-profile.changed"],
    powerSuspend: Protocol.streams["power-sleep.changed"],
    suspendPolicy: Protocol.streams["sleep-policy.changed"]
};

var subscribedStreams = [streams.battery, streams.powerProfile, streams.powerSuspend, streams.suspendPolicy];
