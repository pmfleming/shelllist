.pragma library

const modeDefinitions = [
    { value: "transparent", label: "Ambient", image: "assets/noise-control/ambient.png" },
    { value: "adaptive", label: "Adaptive", image: "assets/noise-control/adaptive.png" },
    { value: "noise-cancelling", label: "Noise cancellation", image: "assets/noise-control/noise-cancellation.png" },
    { value: "off", label: "Off", image: "assets/noise-control/off.png" }
];

function modes() {
    return modeDefinitions.map(function (mode) { return Object.assign({}, mode); });
}

function isAdvertised(control) {
    return ((control && control.available_modes) || []).length > 0;
}

function isSettable(control, mode) {
    return ((control && control.settable_modes) || []).includes(mode);
}

function adjacentSettableIndex(control, currentIndex, delta) {
    for (let index = currentIndex + delta; index >= 0 && index < modeDefinitions.length; index += delta) {
        if (isSettable(control, modeDefinitions[index].value))
            return index;
    }
    return -1;
}
