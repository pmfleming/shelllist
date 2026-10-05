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
        Quickshell.environment = {SHELLLIST_ACCENT: "#6750a4", SHELLLIST_NO_ANIMATIONS: "1"};
    }
    function cleanup(): void {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = previousScheme;
    }
    Component {
        id: destructiveFactory
        Ui.DestructiveIconButton { width: 32; height: 32; accessibleName: "Delete" }
    }
    Component {
        id: focusFactory
        Rectangle {
            width: 200; height: 64
            color: Ui.Theme.selected
            property alias feedback: feedback
            Ui.FocusRing { id: feedback; active: true; cornerRadius: 20 }
        }
    }
    function test_browseMarkerContrast_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_browseMarkerContrast(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const sample = createTemporaryObject(focusFactory, testCase);
        const indicator = findChild(sample, "browseFocusIndicator");
        verify(indicator !== null && indicator.visible);
        compare(sample.feedback.border.width, 0, "browsing does not outline the control");
        for (const seed of ["#6750a4", "#ff0000", "#00ff00", "#0000ff", "#ffffff", "#000000", "#009688"]) {
            // Keep decorative motion enabled: focus paint must still snap.
            Quickshell.environment = {SHELLLIST_ACCENT: seed, SHELLLIST_NO_ANIMATIONS: "false"};
            for (const background of [Ui.Theme.window, Ui.Theme.selected, Ui.Theme.surfaceRaised, Ui.Theme.accent, Ui.Theme.danger]) {
                sample.color = background;
                compare(indicator.color, Ui.Theme.accent);
                compare(indicator.border.color, Ui.Theme.window);
                verify(waitForPolish(sample.Window.window));
                const image = grabImage(sample);
                const point = indicator.mapToItem(sample, 0, indicator.height / 2);
                const ink = image.pixel(Math.round(point.x + 2), Math.round(point.y));
                const backing = image.pixel(Math.round(point.x), Math.round(point.y));
                verify(Contrast.ratio(ink, backing) >= 3, seed + ": actual marker/keyline pixels must reach 3:1");
            }
        }
        sample.feedback.editing = true;
        verify(!indicator.visible);
        compare(sample.feedback.border.width, 2);
        sample.feedback.editing = false;
        verify(indicator.visible, "browse cue returns immediately");
        sample.feedback.active = false;
        verify(!indicator.visible, "focus loss clears the cue immediately");
    }
    function test_destructiveContrast_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function verifyDestructivePair(button): void {
        compare(button.labelColor, Ui.Theme.dangerText);
        const focus = findChild(button, "focusRing");
        const ink = focus.visible ? Contrast.composite(focus.color, button.labelColor) : button.labelColor;
        const fill = focus.visible ? Contrast.composite(focus.color, button.color) : button.color;
        verify(Contrast.ratio(ink, fill) >= 3, "destructive icon must retain 3:1 in the painted state");
    }
    function test_destructiveContrast(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const button = createTemporaryObject(destructiveFactory, testCase);
        verify(button !== null);
        mouseMove(button, 16, 16);
        tryVerify(() => button.hovered);
        verifyDestructivePair(button);
        button.forceActiveFocus();
        verifyDestructivePair(button);
        keyPress(Qt.Key_Space);
        verify(button.pressed);
        verifyDestructivePair(button);
        keyRelease(Qt.Key_Space);
        mouseMove(testCase, 400, 200);
    }
}
