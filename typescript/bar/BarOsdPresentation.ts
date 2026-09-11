function clamp(value: any, minimum: any, maximum: any) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function audioIcon(audio: any) {
    if (!audio || audio.muted || !audio.available)
        return "󰝟";
    const percent = clamp(audio.volume_percent, 0, 100);
    return percent < 34 ? "" : percent < 67 ? "" : "";
}

function osdTimeout(kind: any) {
    const value = String(kind || "");
    if (value.indexOf("privacy") === 0 || value === "brightness-error") return 3000;
    if (["device", "power-profile", "idle-inhibitor"].includes(value)) return 2200;
    return 1400;
}

function outputOsd(audio: any) {
    const value = audio || ({});
    const percent = clamp(value.volume_percent, 0, 100);
    return {
        kind: "audio",
        icon: audioIcon(value),
        label: value.sink_description || "Volume",
        valueLabel: value.muted ? "Muted" : percent + "%",
        percent: percent,
        progressVisible: true,
        timeoutMs: osdTimeout("audio")
    };
}

function inputOsd(audio: any) {
    const value = audio || ({});
    const muted = !!value.input_muted;
    return {
        kind: "input",
        icon: muted ? "󰍭" : "󰍬",
        label: value.source_description || "Microphone",
        valueLabel: muted ? "Muted" : "On",
        percent: muted ? 0 : 100,
        progressVisible: false,
        timeoutMs: osdTimeout("input")
    };
}

function brightnessOsd(brightness: any) {
    const value = brightness || ({});
    const percent = clamp(value.percent, 0, 100);
    return {
        kind: "brightness",
        icon: "󰃠",
        label: "Brightness",
        valueLabel: percent + "%",
        percent: percent,
        progressVisible: true,
        timeoutMs: osdTimeout("brightness")
    };
}

function brightnessErrorOsd() {
    return {
        kind: "brightness-error",
        icon: "󰃠",
        label: "Brightness",
        valueLabel: "Adjustment failed",
        percent: 0,
        progressVisible: false,
        timeoutMs: osdTimeout("brightness-error")
    };
}

function powerProfileIcon(profile: any) {
    const value = profile && profile.profile ? profile.profile : "";
    return value === "power-saver" ? "" : value === "balanced" ? "" : "";
}

function powerProfileOsd(profile: any) {
    const value = profile || ({});
    const name = value.profile || "unknown";
    const labels: Record<string, string> = { "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" };
    return {
        kind: "power-profile",
        icon: powerProfileIcon(value),
        label: "Power profile",
        valueLabel: labels[name] || name,
        percent: 0,
        progressVisible: false,
        timeoutMs: osdTimeout("power-profile")
    };
}

function lockKeyOsd(kind: any, enabled: any) {
    const caps = kind === "caps-lock";
    return {
        kind: kind,
        icon: caps ? "󰪛" : "󰎠",
        label: caps ? "Caps Lock" : "Num Lock",
        valueLabel: enabled ? "On" : "Off",
        percent: enabled ? 100 : 0,
        progressVisible: false,
        timeoutMs: osdTimeout(kind)
    };
}

function keyboardBacklightOsd(percent: any) {
    const value = clamp(percent, 0, 100);
    return {
        kind: "keyboard-backlight",
        icon: "󰌌",
        label: "Keyboard backlight",
        valueLabel: value + "%",
        percent: value,
        progressVisible: true,
        timeoutMs: osdTimeout("keyboard-backlight")
    };
}

function privacyOsd(device: any, active: any) {
    const camera = device === "camera";
    return {
        kind: "privacy-" + device,
        icon: camera ? (active ? "󰄀" : "󰄁") : (active ? "󰍭" : "󰍬"),
        label: camera ? "Camera privacy" : "Microphone privacy",
        valueLabel: active ? "Active" : "Inactive",
        percent: active ? 100 : 0,
        progressVisible: false,
        timeoutMs: osdTimeout("privacy-" + device)
    };
}

function hardwareOsd(previous: any, current: any) {
    const before = previous || ({});
    const value = current || ({});
    if (before.camera_privacy !== value.camera_privacy)
        return privacyOsd("camera", !!value.camera_privacy);
    if (before.microphone_privacy !== value.microphone_privacy)
        return privacyOsd("microphone", !!value.microphone_privacy);
    if (before.caps_lock !== value.caps_lock)
        return lockKeyOsd("caps-lock", !!value.caps_lock);
    if (before.num_lock !== value.num_lock)
        return lockKeyOsd("num-lock", !!value.num_lock);
    if (before.keyboard_backlight_percent !== value.keyboard_backlight_percent
            && value.keyboard_backlight_percent !== null
            && value.keyboard_backlight_percent !== undefined)
        return keyboardBacklightOsd(value.keyboard_backlight_percent);
    return null;
}

function idleInhibited(powerSleep: any) {
    return (powerSleep && Array.isArray(powerSleep.inhibitors) ? powerSleep.inhibitors : [])
        .some(function (inhibitor: any) {
            return String(inhibitor.what || "").split(":").includes("idle");
        });
}

function idleInhibitorOsd(powerSleep: any) {
    const active = idleInhibited(powerSleep);
    return {
        kind: "idle-inhibitor",
        icon: active ? "󰒳" : "󰒲",
        label: "Idle inhibitor",
        valueLabel: active ? "Active" : "Inactive",
        percent: active ? 100 : 0,
        progressVisible: false,
        timeoutMs: osdTimeout("idle-inhibitor")
    };
}

function changedPowerProfileOsd(previous: any, value: any) {
    return previous && previous.available && previous.profile !== value.profile
        ? powerProfileOsd(value) : null;
}

function changedIdleInhibitorOsd(previous: any, value: any) {
    return previous && previous.available
        && idleInhibited(previous) !== idleInhibited(value)
        ? idleInhibitorOsd(value) : null;
}

function availableDomainOsd(previous: any, value: any, renderer: any) {
    return previous && previous.available ? renderer(previous, value) : null;
}

function domainOsd(streams: any, stream: any, previous: any, value: any) {
    const handlers: Record<string, () => any> = ({});
    handlers[streams.powerProfile] = function () { return changedPowerProfileOsd(previous, value); };
    handlers[streams.audio] = function () { return availableDomainOsd(previous, value, audioDeviceOsd); };
    handlers[streams.workspaces] = function () { return availableDomainOsd(previous, value, displayOutputOsd); };
    handlers[streams.powerSleep] = function () { return changedIdleInhibitorOsd(previous, value); };
    handlers[streams.osdHardware] = function () { return availableDomainOsd(previous, value, hardwareOsd); };
    return handlers[stream] ? handlers[stream]() : null;
}

function displayOutputOsd(previous: any, current: any) {
    const before = (previous && previous.monitors || []).map(function (monitor: any) {
        return monitor.name;
    });
    const after = (current && current.monitors || []).map(function (monitor: any) {
        return monitor.name;
    });
    const added = after.find(function (name: any) { return !before.includes(name); });
    const removed = before.find(function (name: any) { return !after.includes(name); });
    if (!added && !removed)
        return null;
    return {
        kind: "device",
        icon: added ? "󰍹" : "󰶐",
        label: "Display output",
        valueLabel: added ? added + " connected" : removed + " disconnected",
        percent: 0,
        progressVisible: false,
        timeoutMs: osdTimeout("device")
    };
}

function audioDeviceOsd(previous: any, current: any) {
    const before = previous || ({});
    const value = current || ({});
    if (before.sink_name !== value.sink_name)
        return {
            kind: "device", icon: "󰓃", label: "Audio output",
            valueLabel: value.sink_description || value.sink_name || "Unavailable",
            percent: 0, progressVisible: false, timeoutMs: osdTimeout("device")
        };
    if (before.source_name !== value.source_name)
        return {
            kind: "device", icon: "󰍬", label: "Audio input",
            valueLabel: value.source_description || value.source_name || "Unavailable",
            percent: 0, progressVisible: false, timeoutMs: osdTimeout("device")
        };
    return null;
}
