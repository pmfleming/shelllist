.pragma library

var streams = {
    changed: "bluetooth.changed",
    pairing: "pairing.request",
    audio: "bluetooth.audio.changed",
    obex: "bluetooth.obex.transfer",
    operation: "bluetooth.operation",
    scan: "bluetooth.scan"
};

var methods = {
    snapshot: "bluetooth.snapshot",
    setPowered: "bluetooth.setPowered",
    scan: "bluetooth.scan",
    adapterOperation: "bluetooth.adapter.operation",
    obexSnapshot: "bluetooth.obex.snapshot",
    obexSend: "bluetooth.obex.send",
    obexRespond: "bluetooth.obex.respond",
    audioSnapshot: "bluetooth.audio.snapshot",
    audioSetProfile: "bluetooth.audio.setProfile",
    pairingRespond: "bluetooth.pairing.respond",
    deviceOperation: "bluetooth.device.operation"
};
