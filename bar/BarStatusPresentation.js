.pragma library
.import "../Core/Duration.js" as Duration
.import "BarIndicators.js" as Indicators

"use strict";
function batteryKnown(battery) {
    return !!battery?.available && typeof battery.percentage === "number" && Number.isFinite(battery.percentage);
}
function batteryFraction(battery) {
    return batteryKnown(battery) ? Math.max(0, Math.min(100, battery.percentage)) / 100 : 0;
}
function batteryStateMark(battery) {
    if (!batteryKnown(battery))
        return "help_outline";
    if (battery.charging)
        return "bolt";
    if (battery.state === "fully-charged" || (battery.plugged && batteryFraction(battery) === 1))
        return "check";
    if (battery.plugged)
        return "power";
    return battery.critical || battery.warning ? "priority_high" : "";
}
function batteryStateLabel(battery) {
    if (battery.charging)
        return "Charging";
    if (battery.state === "fully-charged" || (battery.plugged && batteryFraction(battery) === 1))
        return "Fully charged";
    if (battery.state === "charge-paused")
        return "Charging paused at limit";
    if (battery.state === "charging-inhibited")
        return "Charging inhibited";
    return battery.plugged ? "Plugged in, not charging" : "On battery";
}
function batteryTooltip(battery) {
    if (!batteryKnown(battery))
        return "Battery reading unavailable";
    const value = battery;
    const seconds = value.charging ? value.time_to_full_seconds : value.time_to_empty_seconds;
    const estimate = value.plugged && !value.charging ? "" : " · " + Duration.estimate(seconds);
    return Math.round(batteryFraction(value) * 100) + "% · " + batteryStateLabel(value) + estimate
        + (value.critical ? ". Critical" : value.warning ? ". Low battery" : "")
        + "\n" + Number(value.power_watts || 0).toFixed(1) + " W"
        + "\nHealth " + (value.health_percent ?? "—") + "% · " + (value.cycles ?? "—") + " cycles";
}
function orderedPowerProfiles(profile) {
    const preferred = ["power-saver", "balanced", "performance"];
    const available = (profile?.profiles || []).map(entry => entry.name || "").filter(Boolean);
    return preferred.filter(name => available.includes(name)).concat(available.filter(name => !preferred.includes(name)));
}
function nextPowerProfile(profile) {
    const profiles = orderedPowerProfiles(profile);
    if (profiles.length < 2)
        return "";
    return profiles[(Math.max(0, profiles.indexOf(profile?.profile || "")) + 1) % profiles.length];
}
function networkKind(status) {
    if (!status?.active)
        return "disconnected";
    return status.access_point || status.network?.ssid ? "wifi" : "ethernet";
}
function networkIcon(status) {
    const kind = networkKind(status);
    return kind === "wifi" ? "" : kind === "ethernet" ? "󰈀" : "󰤮";
}
function networkTooltip(status) {
    const kind = networkKind(status);
    if (kind === "disconnected")
        return "Disconnected";
    if (kind === "ethernet")
        return status?.device_iface || "Ethernet";
    const ap = status?.access_point || status?.network || {};
    return (ap.ssid || "Wi-Fi") + " " + Indicators.percent(ap.strength) + "%";
}
function bluetoothTooltip(controller) {
    if (!controller)
        return "Bluetooth unavailable";
    if (!controller.powered)
        return "Bluetooth off";
    const count = (controller.allDevices || []).filter(device => device.connected).length;
    return count ? count + " connected" : "Bluetooth on";
}
function utcOffset(seconds) {
    const total = Number(seconds) || 0, absolute = Math.abs(total);
    return (total < 0 ? "-" : "+") + String(Math.floor(absolute / 3600)).padStart(2, "0")
        + String(Math.floor((absolute % 3600) / 60)).padStart(2, "0");
}
function statusModule(id, text, tooltip, options) {
    return Object.assign({ id, key: id, text, compactText: text, tooltip,
        visible: true, maxDensity: 3, interactive: true, tone: "text", weight: 400,
        primary: "", secondary: "", middle: "", wheelUp: "", wheelDown: "" }, options || {});
}
function layoutDensity(width) {
    const available = Number(width) || 0;
    return available >= 1800 ? 0 : available >= 1200 ? 1 : available >= 700 ? 2 : 3;
}
function moduleText(module, density) {
    return density > 0 ? module.compactText : module.text;
}
function statusModuleEqual(left, right) {
    if (!left || !right)
        return false;
    return Object.keys(left).every(key => left[key] === right[key]);
}
function nextMinuteDelay(nowMilliseconds) {
    return Math.max(1, 60000 - Math.max(0, Number(nowMilliseconds) || 0) % 60000);
}
function batteryTone(battery) {
    if (!batteryKnown(battery))
        return "muted";
    if (battery.critical)
        return "danger";
    if (battery.warning)
        return "warning";
    return "text";
}
function notificationsModule(state) {
    const dnd = !!state.notifications?.dnd, count = state.notifications?.count || 0;
    const urgent = (state.notificationActive?.notifications || []).some(item => item.urgency === "critical" || Number(item.urgency) >= 2);
    return statusModule("notifications", dnd ? "󰂛" : count ? "" : "󰂚", "Notifications: " + count + (dnd ? ". Do not disturb" : "") + (urgent ? ". Urgent" : ""), {
        primary: "notifications", secondary: "activity", middle: "notifications-dnd",
        tone: urgent ? "danger" : dnd ? "muted" : count ? "accent" : "text"
    });
}
function clockModule(now, timezone) {
    return statusModule("clock", Qt.formatDateTime(now, "yyyy-MM-dd  HH:mm"), Qt.formatDateTime(now, "yyyy-MM-dd HH:mm") + " " + (timezone.abbreviation || "") + " " + utcOffset(timezone.utc_offset_seconds), {
        compactText: Qt.formatDateTime(now, "MM-dd HH:mm"), primary: "time-weather"
    });
}
function statusModules(state, now) {
    return [
        statusModule("network", networkIcon(state.network), networkTooltip(state.network), {
            tone: networkKind(state.network) === "disconnected" ? "muted" : "text", primary: "wifi", secondary: "portal"
        }),
        statusModule("bluetooth", "", bluetoothTooltip(state.bluetooth), {
            tone: state.bluetooth?.powered ? "text" : "muted", primary: "bluetooth"
        }),
        statusModule("battery", "battery_full", batteryTooltip(state.battery), {
            primary: "battery", tone: batteryTone(state.battery)
        }),
        notificationsModule(state), clockModule(now, state.timezone)
    ];
}
