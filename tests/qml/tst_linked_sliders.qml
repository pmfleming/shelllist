pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "LinkedSliders"
    when: windowShown
    visible: true
    width: 600
    height: 700
    Component {
        id: factory
        Ui.DetailsNavigation {
            id: nav
            width: tests.width
            height: tests.height
            headerShortcutsEnabled: true
            property real low: 85
            property real high: 90
            property int writes: 0
            property bool sleep: false
            property bool permitted: true
            property alias first: first
            property alias second: second
            contentItem: form
            Column {
                id: form
                width: parent.width
                Ui.LinkedValueSlider {
                    id: first
                    objectName: "first"
                    width: parent.width
                    label: "First"
                    from: 0; to: nav.sleep ? 10080 : 100
                    value: nav.low
                    peerValue: nav.high
                    minimumValue: nav.sleep ? 1 : 0
                    maximumValue: nav.high - 1
                    scaleValues: nav.sleep ? Ui.SliderScale.sleepValues() : Ui.SliderScale.chargeValues()
                    allowNever: nav.sleep
                    unit: nav.sleep ? "min" : "%"
                    interactive: nav.permitted
                    onValueSelected: function(v) { nav.low = v; nav.writes++; }
                }
                Ui.LinkedValueSlider {
                    id: second
                    objectName: "second"
                    width: parent.width
                    label: "Second"
                    from: 0; to: nav.sleep ? 10080 : 100
                    value: nav.high
                    peerValue: nav.low
                    minimumValue: nav.low + 1
                    maximumValue: nav.sleep ? 10080 : 100
                    scaleValues: first.scaleValues
                    allowNever: nav.sleep
                    unit: first.unit
                    onValueSelected: function(v) { nav.high = v; nav.writes++; }
                }
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    function keyClicks(text) { for (const character of text) keyClick(character); }
    function make(properties = {}) {
        const nav = createTemporaryObject(factory, tests, properties);
        verify(nav !== null);
        verify(waitForRendering(nav));
        nav.focusContent();
        compare(nav.currentTarget, nav.first);
        compare(nav.availableFields().length, 2, "labels, axis and exact commands are not field stops");
        return nav;
    }
    function input(field) { return findChild(field, "labeledValueSliderInput"); }
    function test_noEditButtonAndExactCommandMenu() {
        const nav = make();
        const command = nav.first.exactCommand;
        compare(command.width, 0); compare(command.height, 0);
        verify(!command.activeFocusOnTab);
        verify(command.Accessible.ignored, "no phantom accessible button on the slider row");
        compare(command.parent, nav.first, "command metadata is outside the row's layout hosts");
        compare(nav.contentCommands.length, 1, "only the current field exposes its exact command");
        compare(nav.contentCommands[0], command);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => nav.commandMenuOpen);
        const menu = findChild(nav, "detailsCommandMenu");
        compare(menu.count, 1);
        keyClick(Qt.Key_Return);
        tryVerify(() => nav.first.exactDialog.visible);
        tryVerify(() => nav.first.exactDialog.ownsKeyboardFocus);
        verify(!nav.commandMenuOpen);
        compare(nav.writes, 0);
        keyClick(Qt.Key_Escape);
        compare(nav.currentTarget, nav.first);
        tryVerify(() => nav.browsing);
        nav.cycleFocus(false);
        compare(nav.currentTarget, nav.second);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => nav.commandMenuOpen);
        keyClick(Qt.Key_Return);
        tryVerify(() => nav.second.exactDialog.visible);
        verify(!nav.first.exactDialog.visible);
        keyClick(Qt.Key_Escape);
        compare(nav.writes, 0);
    }
    function test_chargeStepsConstraintsAndTransactions() {
        const nav = make({low: 70});
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right); compare(nav.first.value, 75);
        keyClick(Qt.Key_Right); compare(nav.first.value, 76);
        compare(nav.low, 70); compare(nav.writes, 0);
        keyClick(Qt.Key_Left); keyClick(Qt.Key_Left); compare(nav.first.value, 70);
        keyClick(Qt.Key_End); compare(nav.first.value, 89); compare(nav.high, 90);
        keyClick(Qt.Key_Right); compare(nav.first.value, 89);
        keyClick(Qt.Key_Escape); compare(nav.first.value, 70); compare(nav.writes, 0);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Tab);
        compare(nav.low, 75); compare(nav.writes, 1); compare(nav.currentTarget, nav.second);
        verify(nav.editing);
        keyClick(Qt.Key_Home); compare(nav.second.value, 76);
        keyClick(Qt.Key_Backtab); compare(nav.high, 76); compare(nav.currentTarget, nav.first);
        verify(nav.editing);
        keyClick(Qt.Key_Escape);
    }
    function test_progressiveSleepAndExactNever() {
        const nav = make({sleep: true, low: 25, high: 720});
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right); compare(nav.first.value, 30);
        keyClick(Qt.Key_Right); compare(nav.first.value, 45);
        keyClick(Qt.Key_Right); compare(nav.first.value, 60);
        keyClick(Qt.Key_Right); compare(nav.first.value, 90);
        keyClick(Qt.Key_End); compare(nav.first.value, 480);
        keyClick(Qt.Key_Escape); compare(nav.first.value, 25);
        keyClick(Qt.Key_V, Qt.AltModifier);
        const dialog = nav.first.exactDialog;
        tryVerify(() => dialog.visible);
        const exact = findChild(dialog, "promptInput");
        exact.focusInput(true);
        keyClicks("1440");
        verify(!dialog.acceptEnabled, "an exact value cannot cross the peer");
        exact.focusInput(true); keyClicks("0");
        verify(dialog.acceptEnabled); compare(nav.writes, 0);
        keyClick(Qt.Key_Return);
        tryVerify(() => !dialog.visible);
        compare(nav.low, 0); compare(nav.first.valueText, "Never"); compare(nav.writes, 1);
    }
    function test_exactOffScaleAndInvalidInput() {
        const nav = make({low: 37});
        verify(!input(nav.first).onScale);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Escape);
        compare(nav.low, 37); compare(nav.writes, 0, "opening never rounds an off-scale source");
        keyClick(Qt.Key_V, Qt.AltModifier);
        const dialog = nav.first.exactDialog;
        tryVerify(() => dialog.visible);
        const exact = findChild(dialog, "promptInput");
        exact.focusInput(true); keyClicks("62junk"); verify(!dialog.acceptEnabled);
        exact.focusInput(true); keyClicks("62.5"); verify(!dialog.acceptEnabled);
        exact.focusInput(true); keyClicks("62"); verify(dialog.acceptEnabled);
        compare(nav.writes, 0); keyClick(Qt.Key_Escape);
        compare(nav.low, 37); compare(nav.writes, 0);
        keyClick(Qt.Key_V, Qt.AltModifier); tryVerify(() => dialog.visible);
        exact.focusInput(true); keyClicks("62"); keyClick(Qt.Key_Return);
        tryVerify(() => !dialog.visible);
        compare(nav.low, 62); compare(nav.writes, 1, "exact intermediate value is preserved");
        keyClick(Qt.Key_V, Qt.AltModifier); tryVerify(() => dialog.visible);
        nav.suspendView();
        verify(!dialog.visible); compare(nav.writes, 1, "surface suspension discards modal input");
    }
    function test_pointerDraftBlurAndSnapshot() {
        const nav = make();
        const slider = input(nav.first);
        mousePress(slider, slider.width / 2, slider.height / 2);
        mouseMove(slider, slider.width - 1, slider.height / 2);
        mouseRelease(slider, slider.width - 1, slider.height / 2);
        compare(nav.first.value, 89); compare(nav.low, 85); compare(nav.writes, 0);
        nav.low = 80;
        compare(nav.first.value, 89, "snapshot does not replace the active draft");
        nav.second.focusInput();
        compare(nav.first.value, 80, "focus exit reveals latest source");
        compare(nav.writes, 0);
        keyClick(Qt.Key_Escape);
        nav.currentTarget = nav.first; nav.focusContent();
        keyClick(Qt.Key_Return); keyClick(Qt.Key_End);
        nav.high = 86;
        keyClick(Qt.Key_Return);
        compare(nav.low, 80); compare(nav.writes, 0, "changed peer is revalidated at save");
        verify(nav.first.validationError.length > 0);
        nav.low = 77; compare(nav.first.value, 77, "source binding survives rejection");
    }
    function test_dragEscapeAndExactStaleGuard() {
        const nav = make();
        const slider = input(nav.first);
        mousePress(slider, slider.width / 2, slider.height / 2);
        keyClick(Qt.Key_Escape);
        mouseMove(slider, slider.width - 1, slider.height / 2);
        mouseRelease(slider, slider.width - 1, slider.height / 2);
        compare(nav.first.value, 85); compare(nav.writes, 0);
        keyClick(Qt.Key_V, Qt.AltModifier);
        const dialog = nav.first.exactDialog;
        tryVerify(() => dialog.visible);
        nav.high = 95;
        verify(!dialog.acceptEnabled, "a modal cannot reinterpret a changed pair");
        keyClick(Qt.Key_Return); compare(nav.writes, 0);
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_V, Qt.AltModifier); tryVerify(() => dialog.visible);
        nav.permitted = false;
        tryVerify(() => !dialog.visible, 5000, "capability loss closes the exact editor");
        compare(nav.writes, 0);
    }
    function test_touchUsesTheSameNonLinearRuler() {
        const nav = make();
        const slider = input(nav.first);
        const touch = touchEvent(slider);
        touch.press(0, slider, 2, slider.height / 2).commit();
        touch.move(0, slider, slider.width / 2, slider.height / 2).commit();
        touch.release(0, slider, slider.width / 2, slider.height / 2).commit();
        compare(nav.first.value, 85, "middle of the focused charging ruler is 85%, not 50%");
        compare(nav.writes, 0);
        touch.press(0, slider, slider.width / 2, slider.height / 2).commit();
        touch.move(0, slider, slider.width - 1, slider.height / 2).commit();
        touch.release(0, slider, slider.width - 1, slider.height / 2).commit();
        compare(nav.first.value, 89); compare(nav.writes, 0);
        keyClick(Qt.Key_Escape); compare(nav.first.value, 85);
    }
    function test_accessibleActionsUseDomainValuesAndDeferredSave() {
        const nav = make({low: 70});
        const slider = input(nav.first);
        slider.Accessible.increaseAction();
        compare(slider.value, 75); compare(nav.low, 70); compare(nav.writes, 0);
        verify(slider.Accessible.description.includes("75%"));
        slider.Accessible.increaseAction(); compare(slider.value, 76);
        slider.Accessible.decreaseAction(); compare(slider.value, 75);
        keyClick(Qt.Key_Return); compare(nav.low, 75); compare(nav.writes, 1);
    }
    function test_fixedGeometryAndRtl() {
        const nav = make({width: 340});
        compare(input(nav.first).width, input(nav.second).width);
        const marker = findChild(input(nav.first), "sliderPeerMarker");
        const before = marker.x;
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Home);
        compare(marker.x, before, "ruler and companion do not rescale during editing");
        keyClick(Qt.Key_Escape);
        input(nav.first).LayoutMirroring.enabled = true;
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Left);
        compare(nav.first.value, 86, "RTL left increases along mirrored ruler");
        keyClick(Qt.Key_Escape);
        nav.low = 50; nav.high = 75;
        keyClick(Qt.Key_Return); keyClick(Qt.Key_End);
        compare(nav.first.value, 70, "coarse boundary selects the previous valid stop");
        compare(nav.writes, 0);
    }
}
