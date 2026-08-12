.pragma library

// Material Design glyphs bundled by Nerd Fonts. Classification uses only
// BlueZ semantic metadata and typed battery components, never product names.
const glyphs = ({
    bluetooth: "󰂯",                 // md-bluetooth
    blocked: "󰂲",                   // md-bluetooth-off
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

const iconRules = [
    { terms: ["headphones"], glyph: glyphs.headphones },
    { terms: ["headset"], glyph: glyphs.headset },
    { terms: ["speaker", "audio-card"], glyph: glyphs.speaker },
    { terms: ["keyboard"], glyph: glyphs.keyboard },
    { terms: ["mouse"], glyph: glyphs.mouse },
    { terms: ["gaming", "gamepad", "joystick"], glyph: glyphs.controller },
    { terms: ["phone"], glyph: glyphs.phone },
    { terms: ["computer", "laptop"], glyph: glyphs.computer },
    { terms: ["watch"], glyph: glyphs.watch }
];
const typeRules = [
    { terms: ["earbuds"], glyph: glyphs.earbuds },
    { terms: ["headphones"], glyph: glyphs.headphones },
    { terms: ["headset"], glyph: glyphs.headset },
    { terms: ["speaker"], glyph: glyphs.speaker },
    { terms: ["audio device"], glyph: glyphs.bluetoothHeadphones },
    { terms: ["keyboard"], glyph: glyphs.keyboard },
    { terms: ["mouse"], glyph: glyphs.mouse },
    { terms: ["game controller"], glyph: glyphs.controller },
    { terms: ["phone"], glyph: glyphs.phone },
    { terms: ["computer"], glyph: glyphs.computer },
    { terms: ["wearable"], glyph: glyphs.watch }
];
const serviceRules = [
    { terms: ["audio sink"], glyph: glyphs.bluetoothHeadphones },
    { terms: ["handsfree", "headset"], glyph: glyphs.headset }
];

function glyphMatching(text, rules, fallback) {
    const match = rules.find(function (rule) {
        return rule.terms.some(function (term) { return text.indexOf(term) >= 0; });
    });
    return match ? match.glyph : fallback;
}

function forDevice(device) {
    if (hasComponent(device, "left") || hasComponent(device, "right"))
        return glyphs.earbuds;
    const knownType = normalized(device && device.device_type);
    if (knownType && knownType !== "bluetooth device")
        return glyphMatching(knownType, typeRules, glyphs.bluetooth);
    const iconGlyph = glyphMatching(normalized(device && device.icon), iconRules, "");
    return iconGlyph || glyphMatching(serviceText(device), serviceRules, glyphs.bluetooth);
}

function forListDevice(device) {
    return device && device.blocked ? glyphs.blocked : forDevice(device);
}

function forBattery(report) {
    const component = normalized(report && report.component);
    if (component === "left" || component === "right")
        return glyphs.earbuds;
    if (component === "case")
        return glyphs.chargingCase;
    return glyphs.battery;
}
