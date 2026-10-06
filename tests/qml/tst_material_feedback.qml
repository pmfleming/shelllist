pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Battery as Battery
import Shelllist.Launcher as Launcher
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
    Component {
        id: fieldFactory
        Ui.TextField { width: 300; text: "Native text" }
    }
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
    Component {
        id: historyCardFactory
        Battery.BatteryHistoryCard { history: ({points: []}); battery: ({available: false}) }
    }
    Component {
        id: laneChartFactory
        Launcher.ApplicationResourceLaneChart {
            title: "CPU history"
            points: []
            lanes: []
            rangeStartMilliseconds: 1000
            rangeEndMilliseconds: 2000
        }
    }
    Component {
        id: metadataFactory
        Launcher.ApplicationResourceMetadata {
            application: ({running: false})
            latestPoint: ({coverage: 1, sample_count: 2, energy_confidence: "low"})
            uiScale: 1
        }
    }
    function test_customCardsUseOpaqueSharedTone(): void {
        for (const factory of [historyCardFactory, laneChartFactory, metadataFactory]) {
            const card = createTemporaryObject(factory, testCase, {width: 400});
            verify(card !== null);
            const geometry = {width: card.width, height: card.height};
            for (const scheme of [Qt.Light, Qt.Dark]) {
                Ui.Theme.previewColorScheme = scheme;
                compare(card.color, Ui.Theme.surface);
                compare(card.color.a, 1);
                compare(card.border.width, 0);
                verify(waitForPolish(card.Window.window));
                const image = grabImage(card);
                compare(image.pixel(Math.floor(card.width / 2), 3), Ui.Theme.surface,
                    "the outer card fill is the shared opaque tier, not a translucent blend");
                compare(card.width, geometry.width);
                compare(card.height, geometry.height);
            }
            card.visible = false;
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
            for (const background of [Ui.Theme.window, Ui.Theme.selected, Ui.Theme.surfaceRaised, Ui.Theme.input, Ui.Theme.accent, Ui.Theme.danger]) {
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
    Component {
        id: circleFactory
        Ui.ActionButton { icon: "wifi"; label: "Connect"; sizeRole: "primary" }
    }
    function test_circularCommandStates_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_circularCommandStates(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const button = createTemporaryObject(circleFactory, testCase);
        const glyph = findChild(button, "actionLabel");
        compare(glyph.label, "");
        compare(button.Accessible.name, "Connect");
        for (const tone of ["accent", "danger", "warning", "normal"]) {
            button.tone = tone;
            button.forceActiveFocus();
            keyPress(Qt.Key_Space);
            verify(button.pressed);
            compare(button.radius, button.width / 2);
            verify(Contrast.ratio(button.labelColor, button.color) >= 3);
            keyRelease(Qt.Key_Space);
            button.enabled = false;
            compare(button.radius, button.width / 2);
            compare(button.width, button.height);
            button.enabled = true;
        }
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
