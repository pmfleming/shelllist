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
    Component {
        id: buttonFactory
        Rectangle {
            width: 48; height: 48
            color: Ui.Theme.window
            property alias button: button
            property int clicks: 0
            Ui.FlatIconButton {
                id: button
                anchors.fill: parent
                icon: "↻"
                onClicked: parent.clicks++
            }
        }
    }
    function test_disabledFlatButtonRemainsVisible_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_disabledFlatButtonRemainsVisible(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const host = createTemporaryObject(buttonFactory, testCase);
        const button = host.button;
        button.enabled = false;
        verify(button.visible);
        compare(button.labelColor, button.disabledIconColor);
        verify(waitForPolish(host.Window.window));
        const image = grabImage(host);
        let maxContrast = 1;
        for (let y = 8; y < 40; ++y)
            for (let x = 8; x < 40; ++x)
                maxContrast = Math.max(maxContrast, Contrast.ratio(image.pixel(x, y), host.color));
        verify(maxContrast >= 1.8, "disabled glyph remains distinguishable: " + maxContrast);
        mouseClick(button);
        compare(host.clicks, 0);
        button.enabled = true;
        mouseClick(button);
        compare(host.clicks, 1);
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
