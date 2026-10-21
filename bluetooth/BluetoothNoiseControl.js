.pragma library

const modeDefinitions = [
    {
        value: "transparent",
        label: "Ambient",
        image: "assets/noise-control/ambient.png"
    },
    {
        value: "adaptive",
        label: "Adaptive",
        image: "assets/noise-control/adaptive.png"
    },
    {
        value: "noise-cancelling",
        label: "Noise cancellation",
        image: "assets/noise-control/noise-cancellation.png"
    },
    {
        value: "off",
        label: "Off",
        image: "assets/noise-control/off.png"
    }
];

// bt-daemon's vendor-neutral device field also covers non-Fast Pair channels
// (e.g. Sony); older daemons only report the Fast Pair copy.
function state(device) {
    return (device && (device.noise_control || (device.fast_pair || {}).noise_control)) || null;
}

function isAdvertised(control) {
    return ((control && control.available_modes) || []).length > 0;
}

function availableModes(control) {
    const available = (control && control.available_modes) || [];
    return modeDefinitions.filter(function (mode) {
        return available.includes(mode.value);
    }).map(function (mode) {
        return Object.assign({}, mode, {
            enabled: ((control && control.settable_modes) || []).includes(mode.value)
        });
    });
}

function canSet(device) {
    return !!device.connected && !!(device.capabilities || {}).can_set_noise_control
        && availableModes(state(device)).some(mode => mode.enabled);
}

function isActive(control, mode) {
    return !!control && control.active_mode === mode;
}

function activeMode(control) {
    const active = modeDefinitions.find(function (mode) {
        return isActive(control, mode.value);
    });
    return active ? Object.assign({}, active) : {
        value: "",
        label: "Unknown",
        image: ""
    };
}
