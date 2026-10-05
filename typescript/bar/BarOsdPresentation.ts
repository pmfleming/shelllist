interface AudioState {
    available?: boolean;
    muted?: boolean;
    volume_percent?: number;
    input_muted?: boolean;
    sink_name?: string;
    sink_description?: string;
    source_name?: string;
    source_description?: string;
}
interface PowerProfileState {
    available?: boolean;
    profile?: string;
}
interface PowerSuspendState {
    available?: boolean;
    inhibitors?: { what?: string }[];
}
interface HardwareState {
    available?: boolean;
    camera_privacy?: boolean;
    microphone_privacy?: boolean;
    caps_lock?: boolean;
    num_lock?: boolean;
    keyboard_backlight_percent?: number | null;
}
interface WorkspaceMonitors {
    available?: boolean;
    monitors?: { name: string }[];
}
// A domain-event payload; which fields exist depends on the stream.
type OsdDomain = AudioState & PowerProfileState & PowerSuspendState & HardwareState & WorkspaceMonitors;
type OsdStreams = Readonly<Record<"powerProfile" | "audio" | "workspaces" | "powerSuspend" | "osdHardware", string>>;
interface Osd {
    kind: string;
    icon: string;
    label: string;
    valueLabel: string;
    percent: number;
    progressVisible: boolean;
    timeoutMs: number;
}
type Maybe<T> = T | null | undefined;

declare const Indicators: {
    percent(value: unknown): number;
    audioIcon(audio: Maybe<AudioState>): string;
    powerProfileIcon(profile: Maybe<PowerProfileState>): string;
};

function osdTimeout(kind: Maybe<string>) {
    const value = String(kind || "");
    if (value.indexOf("privacy") === 0 || value === "brightness-error") return 3000;
    if (["device", "power-profile", "idle-inhibitor"].includes(value)) return 2200;
    return 1400;
}

// One complete presentation schema; renderers supply only their differences.
function osd(kind: string, presentation: Partial<Omit<Osd, "kind">>): Osd {
    return Object.assign({
        kind: kind,
        icon: "",
        label: "",
        valueLabel: "",
        percent: 0,
        progressVisible: false,
        timeoutMs: osdTimeout(kind)
    }, presentation);
}

function outputOsd(audio: Maybe<AudioState>): Osd {
    const value: AudioState = audio || ({});
    const percent = Indicators.percent(value.volume_percent);
    return osd("audio", {
        icon: Indicators.audioIcon(value),
        label: value.sink_description || "Volume",
        valueLabel: value.muted ? "Muted" : percent + "%",
        percent: percent,
        progressVisible: true
    });
}

function inputOsd(audio: Maybe<AudioState>): Osd {
    const value: AudioState = audio || ({});
    const muted = !!value.input_muted;
    return osd("input", {
        icon: muted ? "󰍭" : "󰍬",
        label: value.source_description || "Microphone",
        valueLabel: muted ? "Muted" : "On",
        percent: muted ? 0 : 100
    });
}

function brightnessOsd(brightness: Maybe<{ percent?: number }>): Osd {
    const value: { percent?: number } = brightness || ({});
    const percent = Indicators.percent(value.percent);
    return osd("brightness", {
        icon: "󰃠",
        label: "Brightness",
        valueLabel: percent + "%",
        percent: percent,
        progressVisible: true
    });
}

function brightnessErrorOsd(): Osd {
    return osd("brightness-error", {
        icon: "󰃠",
        label: "Brightness",
        valueLabel: "Adjustment failed"
    });
}

function powerProfileOsd(profile: Maybe<PowerProfileState>): Osd {
    const value: PowerProfileState = profile || ({});
    const name = value.profile || "unknown";
    const labels: Record<string, string> = { "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" };
    return osd("power-profile", {
        icon: Indicators.powerProfileIcon(value),
        label: "Power profile",
        valueLabel: labels[name] || name
    });
}

function lockKeyOsd(kind: string, enabled: boolean): Osd {
    const caps = kind === "caps-lock";
    return osd(kind, {
        icon: caps ? "󰪛" : "󰎠",
        label: caps ? "Caps Lock" : "Num Lock",
        valueLabel: enabled ? "On" : "Off",
        percent: enabled ? 100 : 0
    });
}

function keyboardBacklightOsd(percent: unknown): Osd {
    const value = Indicators.percent(percent);
    return osd("keyboard-backlight", {
        icon: "󰌌",
        label: "Keyboard backlight",
        valueLabel: value + "%",
        percent: value,
        progressVisible: true
    });
}

function privacyOsd(device: string, active: boolean): Osd {
    const camera = device === "camera";
    return osd("privacy-" + device, {
        icon: camera ? (active ? "󰄀" : "󰄁") : (active ? "󰍭" : "󰍬"),
        label: camera ? "Camera privacy" : "Microphone privacy",
        valueLabel: active ? "Active" : "Inactive",
        percent: active ? 100 : 0
    });
}

function hardwareOsd(previous: Maybe<HardwareState>, current: Maybe<HardwareState>): Osd | null {
    const before: HardwareState = previous || ({});
    const value: HardwareState = current || ({});
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

function idleInhibited(powerSuspend: Maybe<PowerSuspendState>) {
    return (powerSuspend && Array.isArray(powerSuspend.inhibitors) ? powerSuspend.inhibitors : [])
        .some(function (inhibitor: { what?: string }) {
            return String(inhibitor.what || "").split(":").includes("idle");
        });
}

function idleInhibitorOsd(powerSuspend: Maybe<PowerSuspendState>): Osd {
    const active = idleInhibited(powerSuspend);
    return osd("idle-inhibitor", {
        icon: active ? "󰒳" : "󰒲",
        label: "Idle inhibitor",
        valueLabel: active ? "Active" : "Inactive",
        percent: active ? 100 : 0
    });
}

function changedPowerProfileOsd(previous: Maybe<PowerProfileState>, value: PowerProfileState) {
    return previous && previous.available && previous.profile !== value.profile
        ? powerProfileOsd(value) : null;
}

function changedIdleInhibitorOsd(previous: Maybe<PowerSuspendState>, value: PowerSuspendState) {
    return previous && previous.available
        && idleInhibited(previous) !== idleInhibited(value)
        ? idleInhibitorOsd(value) : null;
}

function availableDomainOsd(previous: Maybe<OsdDomain>, value: OsdDomain,
    renderer: (previous: OsdDomain, value: OsdDomain) => Osd | null) {
    return previous && previous.available ? renderer(previous, value) : null;
}

function domainOsd(streams: OsdStreams, stream: string, previous: Maybe<OsdDomain>, value: OsdDomain) {
    const handlers: Record<string, () => Osd | null> = ({});
    handlers[streams.powerProfile] = function () { return changedPowerProfileOsd(previous, value); };
    handlers[streams.audio] = function () { return availableDomainOsd(previous, value, audioDeviceOsd); };
    handlers[streams.workspaces] = function () { return availableDomainOsd(previous, value, displayOutputOsd); };
    handlers[streams.powerSuspend] = function () { return changedIdleInhibitorOsd(previous, value); };
    handlers[streams.osdHardware] = function () { return availableDomainOsd(previous, value, hardwareOsd); };
    return handlers[stream] ? handlers[stream]() : null;
}

function displayOutputOsd(previous: Maybe<WorkspaceMonitors>, current: Maybe<WorkspaceMonitors>): Osd | null {
    const before = (previous && previous.monitors || []).map(function (monitor: { name: string }) {
        return monitor.name;
    });
    const after = (current && current.monitors || []).map(function (monitor: { name: string }) {
        return monitor.name;
    });
    const added = after.find(function (name: string) { return !before.includes(name); });
    const removed = before.find(function (name: string) { return !after.includes(name); });
    if (!added && !removed)
        return null;
    return osd("device", {
        icon: added ? "󰍹" : "󰶐",
        label: "Display output",
        valueLabel: added ? added + " connected" : removed + " disconnected"
    });
}

function audioDeviceOsd(previous: Maybe<AudioState>, current: Maybe<AudioState>): Osd | null {
    const before: AudioState = previous || ({});
    const value: AudioState = current || ({});
    if (before.sink_name !== value.sink_name)
        return osd("device", {
            icon: "󰓃", label: "Audio output",
            valueLabel: value.sink_description || value.sink_name || "Unavailable"
        });
    if (before.source_name !== value.source_name)
        return osd("device", {
            icon: "󰍬", label: "Audio input",
            valueLabel: value.source_description || value.source_name || "Unavailable"
        });
    return null;
}
