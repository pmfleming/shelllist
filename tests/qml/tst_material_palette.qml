import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "MaterialPalette"

    function init(): void {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
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

}
