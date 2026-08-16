.pragma library

const modeDefinitions = [
    { value: "transparent", label: "Ambient", image: "assets/noise-control/ambient.png" },
    { value: "adaptive", label: "Adaptive", image: "assets/noise-control/adaptive.png" },
    { value: "noise-cancelling", label: "Noise cancellation", image: "assets/noise-control/noise-cancellation.png" },
    { value: "off", label: "Off", image: "assets/noise-control/off.png" }
];

function isAdvertised(control) {
    return ((control && control.available_modes) || []).length > 0;
}

function availableModes(control) {
    const available = (control && control.available_modes) || [];
    return modeDefinitions
        .filter(function (mode) { return available.includes(mode.value); })
        .map(function (mode) { return Object.assign({}, mode); });
}

function isActive(control, mode) {
    return !!control && control.active_mode === mode;
}

function activeLabel(control) {
    const active = modeDefinitions.find(function (mode) { return isActive(control, mode.value); });
    return active ? active.label : "Unknown";
}
