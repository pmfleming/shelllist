.pragma library

const componentOrder = ({ left: 0, right: 1, case: 2, main: 3 });
const visualComponentOrder = ({ left: 0, case: 1, right: 2, main: 3 });
const componentImages = ({
    left: "assets/audio/left-earbud.png",
    right: "assets/audio/right-earbud.png",
    case: "assets/audio/charging-case.png"
});
const deviceImageRules = [
    { terms: ["earbuds"], image: "assets/audio/left-earbud.png" },
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

function visuallySorted(reports) {
    return (reports || []).slice().sort(function (left, right) {
        const leftComponent = componentName(left);
        const rightComponent = componentName(right);
        const leftOrder = visualComponentOrder[leftComponent] === undefined ? 100 : visualComponentOrder[leftComponent];
        const rightOrder = visualComponentOrder[rightComponent] === undefined ? 100 : visualComponentOrder[rightComponent];
        return leftOrder - rightOrder;
    });
}

function visualOrdered(reports) {
    return visuallySorted(ordered(reports));
}

function rememberedComponents(device) {
    const seen = ({});
    const components = ((device && device.components) || []).map(function (component) {
        return String(component || "").toLowerCase();
    }).filter(function (component) {
        if (!componentImages[component] || seen[component])
            return false;
        seen[component] = true;
        return true;
    });
    const knownType = String((device && device.device_type) || "").toLowerCase();
    return components.length > 0 || knownType !== "earbuds" ? components : ["left", "right"];
}

function displayReports(device) {
    const current = ordered((device && device.battery) || []);
    const components = rememberedComponents(device);
    if (components.length === 0)
        return current.length > 0 ? visualOrdered(current) : [{ component: "main", percentage: -1, source: "" }];
    const byComponent = ({});
    current.forEach(function (report) {
        const component = componentName(report);
        if (componentImages[component])
            byComponent[component] = report;
    });
    const display = components.map(function (component) {
        return byComponent[component] || {
            component: component,
            percentage: -1,
            source: "remembered-presentation"
        };
    });
    current.forEach(function (report) {
        const component = componentName(report);
        if (componentImages[component] && components.indexOf(component) < 0)
            display.push(report);
    });
    return visuallySorted(display);
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

function serviceImage(device) {
    const services = serviceText(device);
    const headset = services.indexOf("handsfree") >= 0 || services.indexOf("headset") >= 0;
    if (headset)
        return "assets/audio/headset.png";
    return services.indexOf("audio sink") >= 0
        ? "assets/audio/headphones.png" : unknownDeviceImage;
}

function deviceImage(device) {
    const knownType = String((device && device.device_type) || "").toLowerCase();
    const typeImage = matchingDeviceImage(knownType);
    if (typeImage)
        return typeImage;
    if (knownType && knownType !== "bluetooth device")
        return unknownDeviceImage;
    const icon = String((device && device.icon) || "").toLowerCase();
    return matchingDeviceImage(icon) || serviceImage(device);
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
