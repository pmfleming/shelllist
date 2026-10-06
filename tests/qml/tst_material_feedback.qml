pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui
import "ColorContrast.js" as Contrast

TestCase {
    id: testCase
    name: "MaterialFeedback"
    when: windowShown
    visible: true
    width: 500
    height: 240
    property int previousScheme

    function init(): void {
        failOnWarning(/.*/);
        previousScheme = Ui.Theme.previewColorScheme;
    }
    function cleanup(): void {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = previousScheme;
    }
    Component {
        id: fieldFactory
        Ui.TextField { width: 300; text: "Native text" }
    }
    // Keep actual painted contrast, not per-wrapper token/geometry snapshots.
    function test_filledFieldContrast_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_filledFieldContrast(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const field = createTemporaryObject(fieldFactory, testCase);
        const input = findChild(field, "fieldInput");
        const marker = findChild(field, "browseFocusIndicator");
        for (const seed of ["#6750a4", "#ff0000", "#00ff00", "#0000ff", "#ffffff", "#000000", "#009688"]) {
            Quickshell.environment = {SHELLLIST_ACCENT: seed};
            for (const state of ["rest", "browse", "edit", "error"]) {
                field.browseFocused = state === "browse";
                field.focused = state === "edit";
                field.inputValid = state !== "error";
                verify(waitForPolish(field.Window.window));
                const image = grabImage(field);
                const fill = image.pixel(150, 28);
                verify(Contrast.ratio(input.color, fill) >= 4.5, seed + ": text on actual " + state + " fill");
                if (state !== "edit")
                    verify(Contrast.ratio(image.pixel(150, 55), fill) >= 3, seed + ": bottom keyline on filled field");
                if (state === "browse") {
                    const point = marker.mapToItem(field, 0, marker.height / 2);
                    verify(Contrast.ratio(image.pixel(Math.round(point.x + 2), Math.round(point.y)), image.pixel(Math.round(point.x), Math.round(point.y))) >= 3);
                }
            }
        }
    }
}
