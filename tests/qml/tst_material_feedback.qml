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
