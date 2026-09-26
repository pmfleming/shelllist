import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "MaterialPalette"

    Ui.MaterialPalette {
        id: palette
    }

    function test_reactsToSeedAndMode(): void {
        palette.seedColor = "#6750a4";
        palette.dark = false;
        const lightPrimary = String(palette.primary);
        const lightSurface = String(palette.surface);
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
