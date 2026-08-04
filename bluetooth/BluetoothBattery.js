.pragma library

const componentOrder = ({ left: 0, right: 1, case: 2, main: 3 });
const visualComponentOrder = ({ left: 0, case: 1, right: 2, main: 3 });
const componentImages = ({
    left: "assets/audio/left-earbud.png",
    right: "assets/audio/right-earbud.png",
    case: "assets/audio/charging-case.png"
});
const deviceImageRules = [
    { terms: ["headphones"], image: "assets/audio/headphones.png" },
    { terms: ["headset"], image: "assets/audio/headset.png" },
    { terms: ["speaker", "audio-card"], image: "assets/devices/speaker.png" },
    { terms: ["keyboard"], image: "assets/devices/keyboard.png" },
    { terms: ["mouse"], image: "assets/devices/mouse.png" },
    { terms: ["gaming", "gamepad", "joystick"], image: "assets/devices/game-controller.png" },
    { terms: ["phone"], image: "assets/devices/phone.png" },
    { terms: ["computer", "laptop"], image: "assets/devices/computer.png" }
];
const unknownDeviceImage = "assets/devices/unknown-device.png";

function componentName(report) {
    return String((report && report.component) || "").toLowerCase();
}

function isValid(report) {
    return !!report
        && typeof report.percentage === "number"
        && isFinite(report.percentage)
        && report.percentage >= 0
        && report.percentage <= 100;
}

function orderValue(report) {
    const component = componentName(report);
    return componentOrder[component] === undefined ? 100 : componentOrder[component];
}

function ordered(reports) {
    return (reports || [])
        .filter(isValid)
        .map(function (report, index) { return { report: report, index: index }; })
        .sort(function (left, right) {
            const componentDifference = orderValue(left.report) - orderValue(right.report);
            return componentDifference !== 0 ? componentDifference : left.index - right.index;
        })
        .map(function (entry) { return entry.report; });
}

function visualOrdered(reports) {
    return ordered(reports).slice().sort(function (left, right) {
        const leftComponent = componentName(left);
        const rightComponent = componentName(right);
        const leftOrder = visualComponentOrder[leftComponent] === undefined ? 100 : visualComponentOrder[leftComponent];
        const rightOrder = visualComponentOrder[rightComponent] === undefined ? 100 : visualComponentOrder[rightComponent];
        return leftOrder - rightOrder;
    });
}

function serviceText(device) {
    return ((device && device.services) || []).map(function (service) {
        return String(service.label || "").toLowerCase();
    }).join(" ");
}

function matchingDeviceImage(text) {
    const match = deviceImageRules.find(function (rule) {
        return rule.terms.some(function (term) { return text.indexOf(term) >= 0; });
    });
    return match ? match.image : "";
}

function deviceImage(device) {
    const iconImage = matchingDeviceImage(String((device && device.icon) || "").toLowerCase());
    if (iconImage)
        return iconImage;
    const services = serviceText(device);
    if (services.indexOf("handsfree") >= 0 || services.indexOf("headset") >= 0)
        return "assets/audio/headset.png";
    return services.indexOf("audio sink") >= 0
        ? "assets/audio/headphones.png"
        : unknownDeviceImage;
}

function imageFor(device, report) {
    return componentImages[componentName(report)] || deviceImage(device);
}

function batteryState(device, previousCache) {
    const key = device.key || "";
    const current = ordered(device.battery || []);
    const remembered = key ? ((previousCache || ({}))[key] || []) : [];
    return { key: key, retained: current.length > 0 ? current : remembered,
        reports: current.length > 0 ? current : (!device.connected ? remembered : []) };
}

function enrichDevices(devices, previousCache) {
    const cache = ({});
    const enriched = (devices || []).map(function (device) {
        const state = batteryState(device, previousCache);
        if (state.key && state.retained.length > 0)
            cache[state.key] = state.retained;
        return Object.assign({}, device, {
            battery: state.reports,
            battery_last_known: !device.connected && state.reports.length > 0
        });
    });
    return { devices: enriched, cache: cache };
}

function compactLabel(report) {
    const component = componentName(report);
    if (component === "left")
        return "L";
    if (component === "right")
        return "R";
    if (component === "case")
        return "Case";
    if (component === "main")
        return "";
    return (report && (report.label || report.component)) || "Battery";
}

function summary(reports) {
    return ordered(reports).map(function (report) {
        const label = compactLabel(report);
        return (label.length > 0 ? label + " " : "") + report.percentage + "%";
    }).join(" · ");
}

function sourceLabel(reports) {
    const values = ordered(reports);
    if (values.some(function (report) { return report.source === "google-fast-pair-message-stream"; }))
        return "Fast Pair component data";
    if (values.some(function (report) { return report.source === "bluez"; }))
        return "BlueZ aggregate data";
    const source = values.length > 0 ? values[0].source : "";
    return source ? source : "";
}
