.pragma library

// Material Design glyphs bundled by Nerd Fonts. Classification uses only
// BlueZ semantic metadata and typed battery components, never product names.
const glyphs = ({
    bluetooth: "󰂯",                 // md-bluetooth
    earbuds: "󱡏",                   // md-earbuds
    headphones: "󰋋",                // md-headphones
    bluetoothHeadphones: "󰥰",       // md-headphones-bluetooth
    headset: "󰋎",                   // md-headset
    chargingCase: "󰋌",              // md-headphones-box
    speaker: "󰓃",                   // md-speaker
    keyboard: "󰌌",                  // md-keyboard
    mouse: "󰍽",                     // md-mouse
    controller: "󰊴",                // md-google-controller
    phone: "󰄜",                     // md-cellphone
    computer: "󰌢",                  // md-laptop
    watch: "󰖉",                     // md-watch
    battery: "󰁹"                    // md-battery
});

function normalized(value) {
    return String(value || "").toLowerCase();
}

function hasComponent(device, component) {
    return (device && device.battery || []).some(function (report) {
        return normalized(report.component) === component;
    });
}

function serviceText(device) {
    return (device && device.services || []).map(function (service) {
        return normalized(service.label);
    }).join(" ");
}

function forDevice(device) {
    if (hasComponent(device, "left") || hasComponent(device, "right"))
        return glyphs.earbuds;

    const icon = normalized(device && device.icon);
    if (icon.indexOf("headphones") >= 0)
        return glyphs.headphones;
    if (icon.indexOf("headset") >= 0)
        return glyphs.headset;
    if (icon.indexOf("speaker") >= 0 || icon.indexOf("audio-card") >= 0)
        return glyphs.speaker;
    if (icon.indexOf("keyboard") >= 0)
        return glyphs.keyboard;
    if (icon.indexOf("mouse") >= 0)
        return glyphs.mouse;
    if (icon.indexOf("gaming") >= 0 || icon.indexOf("gamepad") >= 0 || icon.indexOf("joystick") >= 0)
        return glyphs.controller;
    if (icon.indexOf("phone") >= 0)
        return glyphs.phone;
    if (icon.indexOf("computer") >= 0 || icon.indexOf("laptop") >= 0)
        return glyphs.computer;
    if (icon.indexOf("watch") >= 0)
        return glyphs.watch;

    const services = serviceText(device);
    if (services.indexOf("audio sink") >= 0)
        return glyphs.bluetoothHeadphones;
    if (services.indexOf("handsfree") >= 0 || services.indexOf("headset") >= 0)
        return glyphs.headset;
    return glyphs.bluetooth;
}

function forBattery(report) {
    const component = normalized(report && report.component);
    if (component === "left" || component === "right")
        return glyphs.earbuds;
    if (component === "case")
        return glyphs.chargingCase;
    return glyphs.battery;
}
