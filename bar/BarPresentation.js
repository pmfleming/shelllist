.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function workspaceIds(state, monitorName) {
    const ids = [1, 2, 3, 4, 5];
    const seen = ({ 1: true, 2: true, 3: true, 4: true, 5: true });
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    workspaces.forEach(function (workspace) {
        if (workspace.id > 0 && workspace.monitor === monitorName && !seen[workspace.id]) {
            seen[workspace.id] = true;
            ids.push(workspace.id);
        }
    });
    return ids.sort(function (left, right) { return left - right; });
}

function workspaceFor(state, workspaceId) {
    const workspaces = state && Array.isArray(state.workspaces) ? state.workspaces : [];
    return workspaces.find(function (workspace) { return workspace.id === workspaceId; }) || null;
}

function activeWorkspaceId(state, monitorName) {
    const monitors = state && Array.isArray(state.monitors) ? state.monitors : [];
    const monitor = monitors.find(function (candidate) { return candidate.name === monitorName; });
    return monitor ? monitor.active_workspace_id : 0;
}

function workspaceGlyph(workspaceId) {
    return workspaceId === 1 ? "󰊠" : workspaceId > 5 ? String(workspaceId) : "";
}

function workspaceIconName(workspaceId) {
    const icons = {
        2: "zen",
        3: "vscode",
        4: "spotify-client",
        5: "scratchpad"
    };
    return icons[workspaceId] || "";
}

function playerFor(media) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    return players.find(function (player) { return player.id === media.active_player; }) || null;
}

function activeWindowFor(state, monitorName) {
    if (!state || !state.active_window)
        return null;
    const focusedMonitor = String(state.focused_monitor || "");
    return focusedMonitor.length === 0 || focusedMonitor === monitorName
        ? state.active_window : null;
}

function windowIconName(window) {
    if (!window)
        return "application-x-executable";
    const value = String(window.initial_class || window.class_name || "").trim();
    return value.length > 0 ? value : "application-x-executable";
}

function playerIcon(player) {
    return player && String(player.desktop_entry || "").toLowerCase().indexOf("spotify") >= 0 ? "" : "";
}

function playbackIcon(player) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : status === "paused" ? "" : "";
}

function playPauseActionIcon(player) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : "";
}

function mediaText(player) {
    if (!player)
        return "";
    const title = player.title || player.identity || "Unknown track";
    return playerIcon(player) + " " + title + "  " + playbackIcon(player);
}

function mediaPositionPercent(player, nowMs) {
    if (!player)
        return 0;
    const length = Math.max(0, Number(player.length_us) || 0);
    if (length <= 0)
        return 0;
    let position = Math.max(0, Number(player.position_us) || 0);
    const status = String(player.playback_status || "").toLowerCase();
    if (status === "playing") {
        const observedAt = Math.max(0, Number(player.position_observed_at_unix_ms) || 0);
        const elapsedMs = Math.max(0, (Number(nowMs) || 0) - observedAt);
        const rate = Math.max(0, Number(player.playback_rate) || 1);
        position += elapsedMs * 1000 * rate;
    }
    return clamp(position / length * 100, 0, 100);
}

function audioIcon(audio) {
    if (!audio || audio.muted || !audio.available)
        return "󰝟";
    const percent = clamp(audio.volume_percent, 0, 100);
    return percent < 34 ? "" : percent < 67 ? "" : "";
}

function outputOsd(audio) {
    const value = audio || ({});
    const percent = clamp(value.volume_percent, 0, 100);
    return {
        kind: "audio",
        icon: audioIcon(value),
        label: value.sink_description || "Volume",
        valueLabel: value.muted ? "Muted" : percent + "%",
        percent: percent,
        progressVisible: true
    };
}

function inputOsd(audio) {
    const value = audio || ({});
    const muted = !!value.input_muted;
    return {
        kind: "input",
        icon: muted ? "󰍭" : "󰍬",
        label: value.source_description || "Microphone",
        valueLabel: muted ? "Muted" : "On",
        percent: muted ? 0 : 100,
        progressVisible: false
    };
}

function brightnessOsd(brightness) {
    const value = brightness || ({});
    const percent = clamp(value.percent, 0, 100);
    return {
        kind: "brightness",
        icon: "󰃠",
        label: "Brightness",
        valueLabel: percent + "%",
        percent: percent,
        progressVisible: true
    };
}

function batteryIcon(battery) {
    if (!battery)
        return "󰂑";
    if (battery.charging)
        return "󰂄";
    if (battery.plugged && battery.percentage >= 99)
        return "󰁹";
    if (battery.plugged)
        return "󰚥";
    const icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
    const index = Math.min(icons.length - 1, Math.floor(clamp(battery.percentage, 0, 100) / 10));
    return icons[index];
}

function batterySeconds(battery) {
    if (!battery)
        return 0;
    return battery.charging ? battery.time_to_full_seconds : battery.time_to_empty_seconds;
}

function duration(seconds) {
    const value = Math.max(0, Number(seconds) || 0);
    if (value <= 0)
        return "estimating";
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return hours > 0 ? hours + "h " + minutes + "m" : Math.max(1, minutes) + "m";
}

function batteryTooltip(battery) {
    if (!battery)
        return "Battery unavailable";
    const health = battery.health_percent === null || battery.health_percent === undefined ? "—" : battery.health_percent + "%";
    const cycles = battery.cycles === null || battery.cycles === undefined ? "—" : battery.cycles;
    return battery.percentage + "% • " + duration(batterySeconds(battery))
        + "\n" + Number(battery.power_watts || 0).toFixed(1) + " W"
        + "\nHealth " + health + " • " + cycles + " cycles";
}

function powerProfileIcon(profile) {
    const value = profile && profile.profile ? profile.profile : "";
    return value === "power-saver" ? "" : value === "balanced" ? "" : "";
}

function networkKind(status) {
    if (!status || !status.active)
        return "disconnected";
    return status.access_point || (status.network && status.network.ssid) ? "wifi" : "ethernet";
}

function networkIcon(status) {
    const kind = networkKind(status);
    return kind === "wifi" ? "" : kind === "ethernet" ? "󰈀" : "󰤮";
}

function networkTooltip(status) {
    const kind = networkKind(status);
    if (kind === "disconnected")
        return "Disconnected\nLeft: Wi-Fi popover\nRight: manual portal fallback";
    if (kind === "ethernet")
        return (status.device_iface || "Ethernet") + "\nLeft: Wi-Fi popover\nRight: manual portal fallback";
    const ap = status.access_point || status.network || ({});
    return (ap.ssid || "Wi-Fi") + " " + clamp(ap.strength, 0, 100) + "%"
        + "\nLeft: Wi-Fi popover\nRight: manual portal fallback";
}

function bluetoothTooltip(controller) {
    if (!controller)
        return "Bluetooth unavailable\nLeft: Bluetooth popover";
    if (!controller.powered)
        return "Bluetooth off\nLeft: Bluetooth popover";
    const devices = Array.isArray(controller.allDevices) ? controller.allDevices : [];
    const connected = devices.filter(function (device) { return device.connected; });
    return (connected.length > 0 ? connected.length + " connected" : "Bluetooth on")
        + "\nLeft: Bluetooth popover";
}

function utcOffset(seconds) {
    const total = Number(seconds) || 0;
    const sign = total < 0 ? "-" : "+";
    const absolute = Math.abs(total);
    const hours = Math.floor(absolute / 3600);
    const minutes = Math.floor((absolute % 3600) / 60);
    return sign + String(hours).padStart(2, "0") + String(minutes).padStart(2, "0");
}

function statusModule(id, text, tooltip, options) {
    return Object.assign({
        id: id, text: text, compactText: text, tooltip: tooltip,
        visible: true, maxDensity: 2, interactive: true,
        tone: "text", weight: 400, primary: "", secondary: "", middle: "",
        wheelUp: "", wheelDown: ""
    }, options || ({}));
}

function layoutDensity(width) {
    const available = Number(width) || 0;
    if (available >= 1800) return 0;
    if (available >= 1200) return 1;
    if (available >= 700) return 2;
    return 3;
}

function visibleStatusModules(modules, density) {
    return (modules || []).filter(function (module) {
        return module.visible && density <= (module.maxDensity === undefined ? 2 : module.maxDensity);
    });
}

function moduleText(module, density) {
    return density > 0 && module.compactText !== undefined ? module.compactText : module.text;
}

function networkModule(status) {
    return statusModule("network", networkIcon(status), networkTooltip(status), {
        maxDensity: 3, tone: networkKind(status) === "disconnected" ? "muted" : "text",
        primary: "wifi", secondary: "portal"
    });
}

function updateModule(updates) {
    return statusModule("updates", "󰚰", "A checked and built NixOS update is waiting for automatic safety or manual approval", {
        visible: !!(updates && updates.available && updates.ready), maxDensity: 3,
        tone: "accent", weight: 700, primary: "updates"
    });
}

function bluetoothModule(bluetooth) {
    return statusModule("bluetooth", "", bluetoothTooltip(bluetooth), {
        maxDensity: 1, tone: bluetooth && bluetooth.powered ? "text" : "muted",
        primary: "bluetooth"
    });
}

function audioModule(audio) {
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

function brightnessModule(brightness) {
    const percent = brightness ? brightness.percent : 0;
    return statusModule("brightness", "󰃠", "Brightness: " + percent
        + "%\nLeft click: brighter\nRight click: dimmer", {
        visible: !!(brightness && brightness.available), maxDensity: 1,
        primary: "brightness-up", secondary: "brightness-down",
        wheelUp: "brightness-up", wheelDown: "brightness-down"
    });
}

function batteryTone(battery) {
    if (battery && (battery.charging || battery.plugged)) return "success";
    if (battery && battery.critical) return "danger";
    return battery && battery.warning ? "warning" : "text";
}

function batteryModule(battery) {
    return statusModule("battery",
        batteryIcon(battery) + " " + ((battery && battery.percentage) || 0) + "%",
        batteryTooltip(battery), {
            compactText: batteryIcon(battery), visible: !!(battery && battery.available),
            maxDensity: 3, interactive: false, tone: batteryTone(battery)
        });
}

function powerModule(profile) {
    return statusModule("power", powerProfileIcon(profile), "Power profile: " + (profile.profile || "")
        + "\nDriver: " + (profile.driver || "unknown"), {
        visible: !!profile.available, maxDensity: 1, interactive: false,
        tone: profile.profile === "performance" ? "danger"
            : profile.profile === "power-saver" ? "success" : "accent"
    });
}

function notificationModule(notifications) {
    const count = (notifications && notifications.count) || 0;
    const dnd = !!(notifications && notifications.dnd);
    return statusModule("notifications", " " + count, "Notifications: " + count
        + "\nLeft click: open history\nRight click: toggle do not disturb"
        + (dnd ? "\nDo not disturb is on" : ""), {
        compactText: "", maxDensity: 2, tone: dnd ? "muted" : "text",
        primary: "notifications", secondary: "notifications-dnd"
    });
}

function timezoneModule(timezone) {
    const city = (timezone && timezone.city) || "";
    return statusModule("timezone", "󰅐 " + city, "Timezone city: " + city
        + "\nTimezone is updated automatically from location", {
        visible: !!(timezone && timezone.available), maxDensity: 0, primary: "timezone"
    });
}

function clockModule(now, timezone) {
    return statusModule("clock", Qt.formatDateTime(now, "ddd dd MMM  HH:mm"),
        Qt.formatDateTime(now, "yyyy-MM-dd") + " " + (timezone.abbreviation || "")
            + " " + utcOffset(timezone.utc_offset_seconds), {
            compactText: Qt.formatDateTime(now, "HH:mm"), maxDensity: 3, interactive: false
        });
}

function statusModules(state, now) {
    return [
        networkModule(state.network), updateModule(state.updates),
        bluetoothModule(state.bluetooth), audioModule(state.audio),
        brightnessModule(state.brightness), batteryModule(state.battery),
        powerModule(state.powerProfile), notificationModule(state.notifications),
        timezoneModule(state.timezone), clockModule(now, state.timezone)
    ];
}
