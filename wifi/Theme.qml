pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: theme

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property color hyprActiveBorder: "transparent"
    property color hyprInactiveBorder: "transparent"
    property int hyprRounding: -1
    property bool hyprAnimationsEnabled: true
    property bool hyprAnimationsKnown: false
    property var hyprQueue: []
    property string hyprRequest: ""

    readonly property var noAnimationsOverride: envBoolOrNull("SHELLLIST_NO_ANIMATIONS")
    readonly property bool noAnimations: noAnimationsOverride === null ? (!hyprland || !hyprAnimationsKnown || !hyprAnimationsEnabled) : noAnimationsOverride
    readonly property bool hyprAccentAvailable: alpha(hyprActiveBorder) > 0.01
    readonly property bool hyprInactiveAvailable: alpha(hyprInactiveBorder) > 0.01
    readonly property bool dark: luminance(window) < 0.5

    // Prefer the NixOS theme exported by home.nix/Hyprland. SystemPalette is a
    // fallback only; Qt's GTK palette plugins vary by Qt generation/package set.
    readonly property color window: envColor("SHELLLIST_BG", systemPalette.window)
    readonly property color surface: envColor("SHELLLIST_SURFACE", mix(systemPalette.window, systemPalette.base, 0.32))
    readonly property color surfaceRaised: mix(surface, window, dark ? 0.26 : 0.12)
    readonly property color input: mix(surface, window, dark ? 0.34 : 0.16)
    readonly property color text: envColor("SHELLLIST_TEXT", systemPalette.windowText)
    readonly property color inputText: text
    readonly property color mutedText: envColor("SHELLLIST_SUBTEXT", mix(text, surface, 0.48))
    readonly property color subtleText: mix(mutedText, surface, 0.32)
    readonly property color border: envColor("SHELLLIST_BORDER", hyprInactiveAvailable ? withAlpha(hyprInactiveBorder, 0.72) : mix(systemPalette.mid, surface, 0.35))
    readonly property color strongBorder: envColor("SHELLLIST_STRONG_BORDER", hyprAccentAvailable ? withAlpha(hyprActiveBorder, 0.82) : systemPalette.highlight)
    readonly property color accent: envColor("SHELLLIST_ACCENT", hyprAccentAvailable ? hyprActiveBorder : systemPalette.highlight)
    readonly property color accentText: readableOn(accent)
    readonly property color selected: envColor("SHELLLIST_SELECTED", withAlpha(accent, dark ? 0.30 : 0.18))
    readonly property color hover: withAlpha(accent, dark ? 0.16 : 0.10)
    readonly property color active: envColor("SHELLLIST_SUCCESS", dark ? "#22c55e" : "#15803d")
    readonly property color activeText: readableOn(active)
    readonly property color activeBackground: withAlpha(active, dark ? 0.18 : 0.12)
    readonly property color danger: envColor("SHELLLIST_DANGER", dark ? "#ef4444" : "#dc2626")
    readonly property color dangerText: readableOn(danger)
    readonly property color dangerBackground: withAlpha(danger, dark ? 0.18 : 0.12)
    readonly property color warning: envColor("SHELLLIST_WARNING", dark ? "#fbbf24" : "#b45309")
    readonly property color disabledText: mix(text, surface, 0.62)
    readonly property color overlay: dark ? "#99000000" : "#66ffffff"

    readonly property int nixRadius: envInt("SHELLLIST_RADIUS", -1)
    readonly property int baseRadius: nixRadius >= 0 ? nixRadius : hyprRounding
    readonly property int windowRadius: baseRadius >= 0 ? Math.max(0, baseRadius + 8) : 18
    readonly property int panelRadius: baseRadius >= 0 ? Math.max(0, baseRadius + 2) : 12
    readonly property int cardRadius: baseRadius >= 0 ? Math.max(0, baseRadius) : 10
    readonly property int controlRadius: baseRadius >= 0 ? Math.max(0, Math.round(baseRadius * 0.8)) : 8

    function envText(name) {
        const value = Quickshell.env(name);
        return value === undefined || value === null ? "" : String(value).trim();
    }

    function envColor(name, fallback) {
        const value = envText(name);
        return value.length > 0 ? value : fallback;
    }

    function envInt(name, fallback) {
        const value = envText(name);
        if (value.length === 0)
            return fallback;
        const parsed = parseInt(value, 10);
        return Number.isNaN(parsed) ? fallback : parsed;
    }

    function envBoolOrNull(name) {
        const value = envText(name).toLowerCase();
        if (value.length === 0)
            return null;
        if (["1", "true", "yes", "on", "disabled", "disable", "no-animation", "no-animations"].indexOf(value) >= 0)
            return true;
        if (["0", "false", "no", "off", "enabled", "enable"].indexOf(value) >= 0)
            return false;
        return null;
    }

    function channel(value) {
        return Math.max(0, Math.min(255, parseInt(value, 16))) / 255;
    }

    function alpha(color) {
        return color && color.a !== undefined ? color.a : 1.0;
    }

    function luminance(color) {
        return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    }

    function withAlpha(color, alphaValue) {
        return Qt.rgba(color.r, color.g, color.b, alphaValue);
    }

    function mix(left, right, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(left.r * (1 - t) + right.r * t, left.g * (1 - t) + right.g * t, left.b * (1 - t) + right.b * t, left.a * (1 - t) + right.a * t);
    }

    function readableOn(color) {
        return luminance(color) > 0.58 ? "#111827" : "#f8fafc";
    }

    function parseHyprColor(text, fallback) {
        let match = /rgba\(([0-9a-fA-F]{8})\)/.exec(text);
        if (match) {
            const value = match[1];
            return Qt.rgba(channel(value.slice(0, 2)), channel(value.slice(2, 4)), channel(value.slice(4, 6)), channel(value.slice(6, 8)));
        }

        match = /rgb\(([0-9a-fA-F]{6})\)/.exec(text);
        if (match) {
            const value = match[1];
            return Qt.rgba(channel(value.slice(0, 2)), channel(value.slice(2, 4)), channel(value.slice(4, 6)), 1.0);
        }

        match = /0x([0-9a-fA-F]{8})/.exec(text);
        if (match) {
            const value = match[1];
            return Qt.rgba(channel(value.slice(2, 4)), channel(value.slice(4, 6)), channel(value.slice(6, 8)), channel(value.slice(0, 2)));
        }

        return fallback;
    }

    function applyHyprRounding(text) {
        const roundingMatch = /int:\s*(-?\d+)/.exec(text);
        if (roundingMatch)
            hyprRounding = Math.max(0, parseInt(roundingMatch[1], 10));
    }

    function applyHyprAnimations(text) {
        const match = /(?:int|bool):\s*(\S+)/.exec(text);
        if (!match)
            return;
        hyprAnimationsKnown = true;
        hyprAnimationsEnabled = ["0", "false", "off", "no"].indexOf(match[1].toLowerCase()) < 0;
    }

    function queueHyprOption(name, option) { hyprQueue = hyprQueue.concat([{ name: name, args: ["hyprctl", "getoption", option] }]); }
    function startNextHyprOption() { if (hyprProc.running || hyprQueue.length === 0) return; const request = hyprQueue.shift(); hyprRequest = request.name; hyprProc.exec(request.args); }

    function applyHyprOption(name, text) {
        if (name === "active") hyprActiveBorder = parseHyprColor(text, hyprActiveBorder);
        else if (name === "inactive") hyprInactiveBorder = parseHyprColor(text, hyprInactiveBorder);
        else if (name === "rounding") applyHyprRounding(text);
        else if (name === "animations") applyHyprAnimations(text);
    }

    function refreshHyprOptions() {
        if (!hyprland)
            return;
        queueHyprOption("active", "general:col.active_border");
        queueHyprOption("inactive", "general:col.inactive_border");
        queueHyprOption("rounding", "decoration:rounding");
        queueHyprOption("animations", "animations:enabled");
        startNextHyprOption();
    }

    function refreshHyprAnimations() {
        if (!hyprland)
            return;
        queueHyprOption("animations", "animations:enabled");
        startNextHyprOption();
    }

    Component.onCompleted: refreshHyprOptions()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                theme.refreshHyprOptions();
        }
    }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    Process {
        id: hyprProc
        stdout: StdioCollector {
            id: hyprOut
            waitForEnd: true
        }
        onExited: function (exitCode) { // qmllint disable signal-handler-parameters
            if (exitCode === 0)
                theme.applyHyprOption(theme.hyprRequest, hyprOut.text);
            theme.startNextHyprOption();
        }
    }
}
