pragma Singleton

import Quickshell
import QtQuick

Item {
    id: theme

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property var noAnimationsOverride: envBoolOrNull("SHELLLIST_NO_ANIMATIONS")
    readonly property bool noAnimations: noAnimationsOverride === null ? !hyprland : noAnimationsOverride
    // Only the development gallery/tests set this; the resident host follows desktop.
    property int previewColorScheme: Qt.Unknown
    readonly property int resolvedColorScheme: previewColorScheme === Qt.Unknown ? Application.styleHints.colorScheme : previewColorScheme
    readonly property bool dark: resolvedColorScheme === Qt.Unknown ? luminance(systemPalette.window) < 0.5 : resolvedColorScheme === Qt.Dark
    readonly property color desktopAccent: envColor("SHELLLIST_ACCENT", systemPalette.accent)
    readonly property alias materialPalette: material

    // A desktop accent seeds one coherent scheme; individual desktop colors
    // cannot override foreground/background pairs and invalidate their contrast.
    readonly property color window: material.surface
    readonly property color surface: material.surfaceContainerLow
    readonly property color surfaceRaised: material.surfaceContainerHigh
    readonly property color input: material.surfaceContainerHighest
    readonly property color text: material.surfaceText
    readonly property color inputText: text
    readonly property color mutedText: material.surfaceVariantText
    readonly property color subtleText: mutedText
    readonly property color border: material.outlineVariant
    readonly property color strongBorder: material.primary
    readonly property color accent: material.primary
    readonly property color accentText: material.primaryText
    readonly property color selected: material.secondaryContainer
    readonly property color selectedText: material.secondaryContainerText
    readonly property color hover: withAlpha(text, 0.08)
    readonly property color pressed: withAlpha(text, 0.12)
    readonly property color active: material.success
    readonly property color activeText: material.successText
    readonly property color danger: material.error
    readonly property color dangerText: material.errorText
    readonly property color dangerBackground: material.errorContainer
    readonly property color warning: material.warning
    readonly property color warningText: material.warningText
    readonly property color disabledText: mix(text, surface, 0.62)
    readonly property color overlay: "#66000000"
    readonly property color controlBackground: surfaceRaised
    readonly property color controlBorder: material.outline
    readonly property real shellOpacity: 0.94
    readonly property color shellColor: withAlpha(window, shellOpacity)

    // Resource series remain distinguishable independently of the interactive accent.
    readonly property color resourceCpu: envColor("SHELLLIST_RESOURCE_CPU", dark ? "#60a5fa" : "#2563eb")
    readonly property color resourceMemory: envColor("SHELLLIST_RESOURCE_MEMORY", dark ? "#4ade80" : "#15803d")
    readonly property color resourceGpu: envColor("SHELLLIST_RESOURCE_GPU", dark ? "#fbbf24" : "#b45309")
    readonly property color resourceDisk: envColor("SHELLLIST_RESOURCE_DISK", dark ? "#38bdf8" : "#0369a1")
    readonly property color resourceNetworkReceive: envColor("SHELLLIST_RESOURCE_NETWORK_RECEIVE", dark ? "#c084fc" : "#7e22ce")
    readonly property color resourceNetworkTransmit: envColor("SHELLLIST_RESOURCE_NETWORK_TRANSMIT", dark ? "#22d3ee" : "#0e7490")
    readonly property color resourcePower: envColor("SHELLLIST_RESOURCE_POWER", dark ? "#fb7185" : "#be123c")

    // Forecast artwork has a dark backdrop independently of the desktop palette.
    readonly property color weatherHeroText: "#f4f7fb"
    readonly property color weatherHeroSecondaryText: "#d6dfec"
    readonly property color weatherHeroMutedText: "#aebdd0"
    readonly property color weatherHeroTemperature: "#ffffff"
    readonly property color weatherHeroMetricText: "#e2e9f2"
    readonly property color weatherHeroBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color weatherPrecipitation: Qt.rgba(47 / 255, 140 / 255, 1, 0.22)

    readonly property string fontFamily: envText("SHELLLIST_FONT") || "Noto Sans"
    readonly property string iconFontFamily: envText("SHELLLIST_ICON_FONT") || "JetBrainsMono Nerd Font"

    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 18
    readonly property int minimumVerticalSpacing: Math.ceil(fontSizeLabel / 2)
    readonly property int contentMargin: 14
    readonly property int contentVerticalMargin: 24
    readonly property int popupClosedWidth: 453
    readonly property int popupOpenWidth: 1040
    readonly property int detailsGapWidth: 12
    readonly property real popupHeightRatio: 0.75
    readonly property real densityMinimum: 0.82
    readonly property real densityMaximum: 1.12
    readonly property int densityReferenceHeight: 850

    readonly property int compactControlHeight: 38
    readonly property int controlHeight: 42
    readonly property int headerHeight: 48
    readonly property int statusHeight: 38

    readonly property int fontSizeCaption: 11
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeBody: 13
    readonly property int fontSizeLabel: 14
    readonly property int fontSizeHeading: 16
    readonly property int fontSizeTitle: 20
    readonly property int fontSizeDisplay: 22
    readonly property int fontWeightRegular: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightDemiBold: Font.DemiBold
    readonly property int fontWeightBold: Font.Bold

    readonly property int iconSizeSmall: 15
    readonly property int iconSize: 18
    readonly property int iconSizeLarge: 24

    readonly property int focusRingWidth: 2
    readonly property int focusRingInset: 2

    readonly property real disabledOpacity: 0.45
    readonly property real readOnlyOpacity: 0.72
    readonly property int animationFast: 170
    readonly property int animationInteractive: 170
    readonly property int animationNormal: 220
    // Qt spring parameters, provisionally tuned for small decorative controls.
    readonly property real motionSpring: 4.5
    readonly property real motionDamping: 0.8
    readonly property int pressedCornerRadius: 8
    readonly property int spinnerDuration: 900
    readonly property int easingStandard: Easing.InOutCubic
    readonly property int easingResponsive: Easing.OutCubic
    readonly property int easingGentle: Easing.InOutSine

    readonly property int listRowMinHeight: 42
    readonly property int listRowHeight: 52
    readonly property int listRowMaxHeight: 58
    readonly property int listVisibleRowTarget: 15
    readonly property real listDensityMinimum: 0.86
    readonly property real listDensityMaximum: 1.08

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

    function densityScale(availableHeight, verticalMargin) {
        return Math.max(densityMinimum, Math.min(densityMaximum, (availableHeight - 2 * verticalMargin) / densityReferenceHeight));
    }

    function verticalSpacing(preferred, density) {
        if (preferred <= minimumVerticalSpacing)
            return preferred;
        const boundedDensity = Math.max(densityMinimum, Math.min(1, density));
        const compression = (boundedDensity - densityMinimum) / (1 - densityMinimum);
        return Math.round(minimumVerticalSpacing + (preferred - minimumVerticalSpacing) * compression);
    }

    function listDelegateHeight(availableHeight) {
        return Math.max(listRowMinHeight, Math.min(listRowMaxHeight, availableHeight / listVisibleRowTarget));
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

    MaterialPalette {
        id: material
        seedColor: theme.desktopAccent
        dark: theme.dark
    }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }
}
