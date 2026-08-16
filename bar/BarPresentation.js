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

function workspaceAsset(workspaceId) {
    const assets = {
        2: "assets/zen-workspace.svg",
        3: "assets/vscode-workspace.svg",
        4: "assets/spotify-workspace.svg",
        5: "assets/scratchpad-workspace.svg"
    };
    return assets[workspaceId] || "";
}

function playerFor(media) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    return players.find(function (player) { return player.id === media.active_player; }) || null;
}

function playerIcon(player) {
    return player && String(player.desktop_entry || "").toLowerCase().indexOf("spotify") >= 0 ? "" : "";
}

function playbackIcon(player) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : status === "paused" ? "" : "";
}

function mediaText(player) {
    if (!player)
        return "";
    const title = player.title || player.identity || "Unknown track";
    return playerIcon(player) + " " + title + "  " + playbackIcon(player);
}

function audioIcon(audio) {
    if (!audio || audio.muted || !audio.available)
        return "󰝟";
    const percent = clamp(audio.volume_percent, 0, 100);
    return percent < 34 ? "" : percent < 67 ? "" : "";
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
