pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../nix/qrca" as Scanner
import "ColorContrast.js" as Contrast

TestCase {
    id: testCase
    name: "WifiScannerContrast"
    when: windowShown
    visible: true
    width: 400
    height: 180
    property int activations: 0

    Component {
        id: factory
        Rectangle {
            width: 380; height: 160
            property alias button: button
            Scanner.ScannerButton {
                id: button
                x: 20; y: 20
                width: 240
                text: "Connect"
                onClicked: testCase.activations++
            }
        }
    }

    function test_opaqueReadableStatesAndNativeActions_data() {
        return [{tag: "bright-camera", backdrop: "white"}, {tag: "dark-camera", backdrop: "black"}];
    }
    function test_opaqueReadableStatesAndNativeActions(data) {
        const host = createTemporaryObject(factory, testCase, {color: data.backdrop});
        verify(host !== null);
        const button = host.button;
        activations = 0;
        for (const state of ["normal", "hover", "pressed", "checked", "disabled", "focus"]) {
            button.enabled = state !== "disabled";
            button.checkable = state === "checked";
            button.checked = state === "checked";
            mouseMove(host, host.width - 1, host.height - 1);
            if (state === "hover" || state === "pressed") mouseMove(button, 30, 20);
            if (state === "pressed") mousePress(button, 30, 20);
            if (state === "focus") button.forceActiveFocus(Qt.TabFocusReason);
            wait(20);
            verify(Contrast.ratio(button.foregroundColor, button.surfaceColor) >= 4.5, state + ": text");
            verify(Contrast.ratio(button.outlineColor, button.surfaceColor) >= 3, state + ": outline");
            const image = grabImage(button);
            compare(image.pixel(10, 10), button.surfaceColor, state + ": opaque fill over camera");
            let foregroundPixels = 0;
            for (let y = 4; y < image.height - 4; ++y)
                for (let x = 4; x < image.width - 4; ++x)
                    if (Contrast.ratio(image.pixel(x, y), button.surfaceColor) >= 4.5) foregroundPixels++;
            verify(foregroundPixels > 5, state + ": actual label uses the contrasting foreground");
            verify(button.height >= 44);
            if (state === "pressed") mouseRelease(button, 30, 20);
        }
        button.checkable = false;
        button.enabled = true;
        const before = activations;
        button.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Space);
        compare(activations, before + 1, "native keyboard activation is unchanged");
        button.enabled = false;
        mouseClick(button);
        compare(activations, before + 1, "disabled actions cannot activate");
    }
}
