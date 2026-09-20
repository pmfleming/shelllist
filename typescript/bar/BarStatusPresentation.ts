declare const Duration: { estimate(seconds: any, emptyText?: any): string };
declare const Qt: { formatDateTime(value: any, format: string): string };

function clamp(value: any, minimum: any, maximum: any) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function audioIcon(audio: any) {
    if (!audio || audio.muted || !audio.available)
        return "󰝟";
    const percent = clamp(audio.volume_percent, 0, 100);
    return percent < 34 ? "" : percent < 67 ? "" : "";
}

function batteryIcon(battery: any) {
    if (!battery)
        return "󰂑";
    const level = Math.round(clamp(battery.percentage, 0, 100) / 10);
    const discharging = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
    const charging = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
    return (battery.charging ? charging : discharging)[level];
}

function batterySeconds(battery: any) {
    if (!battery)
        return 0;
    return battery.charging ? battery.time_to_full_seconds : battery.time_to_empty_seconds;
}

function duration(seconds: any) { return Duration.estimate(seconds); }

function batteryTooltip(battery: any) {
    if (!battery)
        return "Battery unavailable";
    const health = battery.health_percent === null || battery.health_percent === undefined ? "—" : battery.health_percent + "%";
    const cycles = battery.cycles === null || battery.cycles === undefined ? "—" : battery.cycles;
    return battery.percentage + "% • " + duration(batterySeconds(battery))
        + "\n" + Number(battery.power_watts || 0).toFixed(1) + " W"
        + "\nHealth " + health + " • " + cycles + " cycles"
        + "\nLeft click: open battery & power settings";
}

function powerProfileIcon(profile: any) {
    const value = profile && profile.profile ? profile.profile : "";
    return value === "power-saver" ? "" : value === "balanced" ? "" : "";
}

function orderedPowerProfiles(profile: any) {
    const preferred = ["power-saver", "balanced", "performance"];
    const available = (profile && Array.isArray(profile.profiles) ? profile.profiles : [])
        .map(function (entry: any) { return entry.name || ""; }).filter(Boolean);
    return preferred.filter(function (name: any) { return available.includes(name); })
        .concat(available.filter(function (name: any) { return !preferred.includes(name); }));
}

function nextPowerProfile(profile: any) {
    const profiles = orderedPowerProfiles(profile);
    if (profiles.length < 2)
        return "";
    const current = profiles.indexOf((profile && profile.profile) || "");
    const index = current < 0 ? 0 : current;
    return profiles[(index + 1) % profiles.length];
}

function networkKind(status: any) {
    if (!status || !status.active)
        return "disconnected";
    return status.access_point || (status.network && status.network.ssid) ? "wifi" : "ethernet";
}

function networkIcon(status: any) {
    const kind = networkKind(status);
    return kind === "wifi" ? "" : kind === "ethernet" ? "󰈀" : "󰤮";
}

function networkTooltip(status: any) {
    const kind = networkKind(status);
    if (kind === "disconnected")
        return "Disconnected\nLeft: Wi-Fi popover\nRight: manual portal fallback";
    if (kind === "ethernet")
        return (status.device_iface || "Ethernet") + "\nLeft: Wi-Fi popover\nRight: manual portal fallback";
    const ap = status.access_point || status.network || ({});
    return (ap.ssid || "Wi-Fi") + " " + clamp(ap.strength, 0, 100) + "%"
        + "\nLeft: Wi-Fi popover\nRight: manual portal fallback";
}

function bluetoothTooltip(controller: any) {
    if (!controller)
        return "Bluetooth unavailable\nLeft: Bluetooth popover";
    if (!controller.powered)
        return "Bluetooth off\nLeft: Bluetooth popover";
    const devices = Array.isArray(controller.allDevices) ? controller.allDevices : [];
    const connected = devices.filter(function (device: any) { return device.connected; });
    return (connected.length > 0 ? connected.length + " connected" : "Bluetooth on")
        + "\nLeft: Bluetooth popover";
}

function utcOffset(seconds: any) {
    const total = Number(seconds) || 0;
    const sign = total < 0 ? "-" : "+";
    const absolute = Math.abs(total);
    const hours = Math.floor(absolute / 3600);
    const minutes = Math.floor((absolute % 3600) / 60);
    return sign + String(hours).padStart(2, "0") + String(minutes).padStart(2, "0");
}

function statusModule(id: any, text: any, tooltip: any, options: any) {
    return Object.assign({
        id: id, text: text, compactText: text, tooltip: tooltip,
        visible: true, maxDensity: 2, interactive: true,
        tone: "text", weight: 400, primary: "", secondary: "", middle: "",
        wheelUp: "", wheelDown: ""
    }, options || ({}));
}

function layoutDensity(width: any) {
    const available = Number(width) || 0;
    if (available >= 1800) return 0;
    if (available >= 1200) return 1;
    if (available >= 700) return 2;
    return 3;
}

function visibleStatusModules(modules: any, density: any) {
    return (modules || []).filter(function (module: any) {
        return module.visible && density <= (module.maxDensity === undefined ? 2 : module.maxDensity);
    });
}

function moduleText(module: any, density: any) {
    return density > 0 && module.compactText !== undefined ? module.compactText : module.text;
}

function statusModuleEqual(left: any, right: any) {
    if (!left || !right)
        return false;
    const fields = ["id", "text", "compactText", "tooltip", "visible", "maxDensity",
        "interactive", "tone", "weight", "primary", "secondary", "middle", "wheelUp",
        "wheelDown"];
    return fields.every(function (field: any) { return left[field] === right[field]; });
}

function nextMinuteDelay(nowMilliseconds: any) {
    const remainder = Math.max(0, Number(nowMilliseconds) || 0) % 60000;
    return Math.max(1, 60000 - remainder);
}

function networkModule(status: any) {
    return statusModule("network", networkIcon(status), networkTooltip(status), {
        maxDensity: 3, tone: networkKind(status) === "disconnected" ? "muted" : "text",
        primary: "wifi", secondary: "portal"
    });
}

interface UpdateJob {
    name: string;
    status: string;
    phase?: string;
    error?: string | null;
}

function updateModule(updates: { available?: boolean; ready?: boolean; jobs?: UpdateJob[] } | null | undefined) {
    const jobs = (updates && updates.jobs) || [];
    const running = jobs.some(function (job) { return job.status === "running"; });
    const problem = jobs.some(function (job) { return job.status === "failed" || job.status === "interrupted" || job.phase === "stale"; });
    const names: Record<string, string> = { system: "NixOS", "ai-tools": "AI tools", "ai-tools-stale": "AI tools freshness" };
    const lines = jobs.map(function (job) {
        const name = names[job.name] || "Updates";
        return name + ": " + (job.phase || job.status) + " · " + job.status + (job.error ? "\n" + job.error : "");
    });
    if (updates && updates.ready)
        lines.unshift("A checked and built NixOS update is waiting for automatic safety or manual approval");
    lines.push("Click to inspect update service journals");
    return statusModule("updates", "󰚰", lines.join("\n"), {
        visible: !!(updates && updates.available && (updates.ready || running || problem)), maxDensity: 3,
        tone: problem ? "warning" : "accent", weight: 700, primary: "updates"
    });
}

function bluetoothModule(bluetooth: any) {
    return statusModule("bluetooth", "", bluetoothTooltip(bluetooth), {
        maxDensity: 1, tone: bluetooth && bluetooth.powered ? "text" : "muted",
        primary: "bluetooth"
    });
}

function audioModule(audio: any) {
    const available = audio && audio.available;
    const tooltip = available
        ? (audio.sink_description || "Audio") + ": " + audio.volume_percent + "%"
            + (audio.muted ? " (muted)" : "")
        : "Audio unavailable";
    return statusModule("audio", audioIcon(audio), tooltip, {
        maxDensity: 2, tone: audio && audio.muted ? "muted" : "text",
        primary: "audio-mixer", secondary: "audio-mute",
        wheelUp: "audio-up", wheelDown: "audio-down"
    });
}

function brightnessModule(brightness: any) {
    const percent = brightness ? brightness.percent : 0;
    return statusModule("brightness", "󰃠", "Brightness: " + percent
        + "%\nLeft click: brighter\nRight click: dimmer", {
        visible: !!(brightness && brightness.available), maxDensity: 1,
        primary: "brightness-up", secondary: "brightness-down",
        wheelUp: "brightness-up", wheelDown: "brightness-down"
    });
}

function displaysModule(displays: any) {
    const outputs = (displays && displays.outputs) || [];
    const icon = outputs.length > 1 ? "󰍺" : "󰍹";
    return statusModule("displays", icon, "Displays", {
        maxDensity: 3, primary: "displays", interactive: true,
        tone: displays && displays.error ? "warning" : "text"
    });
}

function batteryTone(battery: any) {
    if (battery && (battery.charging || battery.plugged)) return "success";
    if (battery && battery.critical) return "danger";
    return battery && battery.warning ? "warning" : "text";
}

function batteryModule(battery: any) {
    return statusModule("battery",
        batteryIcon(battery) + " " + ((battery && battery.percentage) || 0) + "%",
        batteryTooltip(battery), {
            compactText: batteryIcon(battery), visible: !!(battery && battery.available),
            maxDensity: 3, interactive: true, primary: "battery", tone: batteryTone(battery)
        });
}

function powerModule(profile: any) {
    return statusModule("power", powerProfileIcon(profile), "Power profile: " + (profile.profile || "")
        + "\nLeft click: cycle power mode"
        + "\nDriver: " + (profile.driver || "unknown"), {
        visible: !!profile.available, maxDensity: 1, interactive: true,
        primary: "power-profile-next",
        tone: profile.profile === "performance" ? "danger"
            : profile.profile === "power-saver" ? "success" : "accent"
    });
}

function nextEventTime(next: any) {
    if (!next)
        return "";
    return next.all_day ? "All day"
        : Qt.formatDateTime(new Date(next.start_unix_ms), "ddd HH:mm");
}

function activityModule(activity: any, notifications: any) {
    const count = (notifications && notifications.count) || 0;
    const dnd = !!(notifications && notifications.dnd);
    const next = activity && activity.next_event;
    const nextTitle = next ? (next.title || "Untitled event") : "No upcoming events";
    const nextTime = nextEventTime(next);
    return statusModule("activity", "󰃭", "Agenda · Notifications: " + count
        + "\n" + nextTitle + (nextTime ? "\n" + nextTime : "")
        + "\nTodos: " + ((activity && activity.incomplete_todo_count) || 0)
        + (dnd ? "\nDo not disturb is on" : "") + "\nClick: open agenda", {
        compactText: "󰃭", maxDensity: 3,
        tone: dnd ? "muted" : count > 0 || next ? "accent" : "text",
        primary: "activity", secondary: "activity", middle: "activity"
    });
}

function timezoneModule(timezone: any) {
    const city = (timezone && timezone.city) || "";
    return statusModule("timezone", "󰅐 " + city, "Timezone city: " + city
        + "\nTimezone is updated automatically from location"
        + "\nLeft click: open Time & Weather", {
        visible: !!(timezone && timezone.available), maxDensity: 0, primary: "timezone"
    });
}

function clockModule(now: any, timezone: any) {
    return statusModule("clock", Qt.formatDateTime(now, "ddd dd MMM  HH:mm"),
        Qt.formatDateTime(now, "yyyy-MM-dd") + " " + (timezone.abbreviation || "")
            + " " + utcOffset(timezone.utc_offset_seconds)
            + "\nLeft click: open Time & Weather", {
            compactText: Qt.formatDateTime(now, "HH:mm"), maxDensity: 3,
            primary: "time-weather"
        });
}

function statusModules(state: any, now: any) {
    return [
        networkModule(state.network), updateModule(state.updates),
        bluetoothModule(state.bluetooth), audioModule(state.audio),
        brightnessModule(state.brightness), displaysModule(state.displays), batteryModule(state.battery),
        powerModule(state.powerProfile), activityModule(state.activity, state.notifications),
        timezoneModule(state.timezone), clockModule(now, state.timezone)
    ];
}
