pragma Singleton

import Quickshell
import QtQuick

Item {
    id: theme

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property var noAnimationsOverride: envBoolOrNull("SHELLLIST_NO_ANIMATIONS")
    readonly property bool noAnimations: noAnimationsOverride === null ? !hyprland : noAnimationsOverride
    readonly property bool dark: luminance(window) < 0.5

    // Nix/Home Manager environment values are authoritative. SystemPalette is the portable
    // fallback, avoiding a second asynchronous theme source through compositor-private IPC.
    readonly property color window: envColor("SHELLLIST_BG", systemPalette.window)
    readonly property color surface: envColor("SHELLLIST_SURFACE", mix(systemPalette.window, systemPalette.base, 0.32))
    readonly property color surfaceRaised: mix(surface, window, dark ? 0.26 : 0.12)
    readonly property color input: mix(surface, window, dark ? 0.34 : 0.16)
    readonly property color text: envColor("SHELLLIST_TEXT", systemPalette.windowText)
    readonly property color inputText: text
    readonly property color mutedText: envColor("SHELLLIST_SUBTEXT", mix(text, surface, 0.48))
    readonly property color subtleText: mix(mutedText, surface, 0.32)
    readonly property color border: envColor("SHELLLIST_BORDER", mix(systemPalette.mid, surface, 0.35))
    readonly property color strongBorder: envColor("SHELLLIST_STRONG_BORDER", systemPalette.highlight)
    readonly property color accent: envColor("SHELLLIST_ACCENT", systemPalette.highlight)
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

    readonly property string fontFamily: envText("SHELLLIST_FONT") || "Noto Sans"
    readonly property string iconFontFamily: envText("SHELLLIST_ICON_FONT") || "JetBrainsMono Nerd Font"

    readonly property int baseRadius: envInt("SHELLLIST_RADIUS", 10)
    readonly property int windowRadius: Math.max(0, baseRadius + 8)
    readonly property int panelRadius: Math.max(0, baseRadius + 2)
    readonly property int cardRadius: Math.max(0, baseRadius)
    readonly property int controlRadius: Math.max(0, Math.round(baseRadius * 0.8))

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

    function luminance(color) { return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b; }
    function withAlpha(color, alphaValue) { return Qt.rgba(color.r, color.g, color.b, alphaValue); }
    function mix(left, right, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(left.r * (1 - t) + right.r * t, left.g * (1 - t) + right.g * t, left.b * (1 - t) + right.b * t, left.a * (1 - t) + right.a * t);
    }
    function readableOn(color) { return luminance(color) > 0.58 ? "#111827" : "#f8fafc"; }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }
}
