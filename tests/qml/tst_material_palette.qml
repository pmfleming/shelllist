import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui

TestCase {
    name: "MaterialPalette"
    property int savedScheme

    function init(): void {
        savedScheme = Ui.Theme.previewColorScheme;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function cleanup(): void {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = savedScheme;
    }

    SystemPalette {
        id: desktop
        colorGroup: SystemPalette.Active
    }

    function test_themeFollowsReportedDesktopPreference(): void {
        Ui.Theme.previewColorScheme = Qt.Unknown;
        const reported = Application.styleHints.colorScheme;
        compare(Ui.Theme.dark, reported === Qt.Unknown ? Ui.Theme.luminance(desktop.window) < 0.5 : reported === Qt.Dark);
    }

    function test_themePreviewsBothModesWithCoherentRoles(): void {
        Quickshell.environment = {
            SHELLLIST_ACCENT: "#6750a4",
            SHELLLIST_TEXT: "#00ff00",
            SHELLLIST_BG: "#ffffff"
        };
        for (const dark of [false, true]) {
            Ui.Theme.previewColorScheme = dark ? Qt.Dark : Qt.Light;
            compare(Ui.Theme.dark, dark);
            palette.seedColor = "#6750a4";
            palette.dark = dark;
            compare(String(Ui.Theme.accent), String(palette.primary));
            compare(String(Ui.Theme.text), String(palette.surfaceText));
            compare(String(Ui.Theme.window), String(palette.surface));
            compare(String(Ui.Theme.selectedText), String(palette.secondaryContainerText));
            compare(Ui.Theme.controlBackground.a, 1);
            verify(Ui.Theme.shellColor.a > 0.93 && Ui.Theme.shellColor.a < 0.95);
        }
        Quickshell.environment = {
            SHELLLIST_ACCENT: "#009688"
        };
        palette.seedColor = "#009688";
        compare(String(Ui.Theme.accent), String(palette.primary), "seed changes propagate without reload");
    }

    Ui.MaterialPalette {
        id: palette
    }

    function test_foregroundBindingsAreColorsNotSignalHandlers(): void {
        for (const dark of [false, true]) {
            palette.dark = dark;
            for (const role of ["primary", "primaryContainer", "secondary", "secondaryContainer", "tertiary", "tertiaryContainer", "surface", "surfaceVariant", "error", "errorContainer", "success", "warning"]) {
                const upstream = "on" + role[0].toUpperCase() + role.slice(1);
                compare(String(palette[role + "Text"]), palette.roles[upstream], role);
            }
        }
    }

    function test_reactsToSeedAndMode(): void {
        palette.seedColor = "#6750a4";
        palette.dark = false;
        const lightPrimary = String(palette.primary);
        const lightSurface = String(palette.surface);
        compare(String(palette.primary), "#65558f");
        compare(String(palette.primaryText), "#ffffff");
        compare(String(palette.surfaceText), "#1d1b20");
        compare(palette.primary.a, 1);
        compare(palette.surfaceContainerHigh.a, 1);
        verify(lightPrimary !== "#000000");
        palette.dark = true;
        verify(String(palette.primary) !== lightPrimary);
        verify(String(palette.surface) !== lightSurface);
        const darkPrimary = String(palette.primary);
        palette.seedColor = "#009688";
        verify(String(palette.primary) !== darkPrimary);
        palette.seedColor = "#806750a4";
        compare(String(palette.primary), darkPrimary, "seed alpha is not control translucency");
        palette.dark = false;
        compare(String(palette.primary), lightPrimary);
        compare(String(palette.surface), lightSurface);
    }
}
