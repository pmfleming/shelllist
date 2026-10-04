import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui

TestCase {
    name: "SettingsControls"
    when: windowShown
    visible: true
    width: 500
    height: 200

    Component {
        id: sliderFactory
        Ui.PercentageSlider {
            width: 480
            label: "Low battery"
            value: 20
        }
    }
    Component {
        id: bareSliderFactory
        Ui.ValueSlider {
            from: 10
            to: 90
            value: 50
            stepSize: 1
        }
    }
    Component {
        id: segmentsFactory
        Ui.SegmentedControl {
            width: 420
            value: "first"
            options: [
                { value: "first", label: "First" },
                { value: "second", label: "Unavailable", enabled: false },
                { value: "third", label: "Third" }
            ]
            onSelected: function (next) { value = next; }
        }
    }
    SignalSpy {
        id: selection
        signalName: "selected"
    }
    SignalSpy {
        id: edited
        signalName: "edited"
    }

    function init(): void {
        failOnWarning(/.*/);
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: "false" };
    }
    function cleanup(): void {
        edited.target = null;
        selection.target = null;
        Quickshell.environment = ({});
    }
    function test_sliderFeedbackDoesNotTrailItsValue(): void {
        const slider = createTemporaryObject(sliderFactory, this);
        const input = findChild(slider, "labeledValueSliderInput");
        input.forceActiveFocus();
        verify(findChild(input, "focusRing").visible);
        for (const disabledMotion of [false, true]) {
            Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: String(disabledMotion) };
            input.value = input.to;
            compare(input.handle.x, input.leftPadding + input.availableWidth - input.handle.width);
            input.pressed = true;
            input.value = input.from;
            compare(input.handle.x, input.leftPadding, "drag and keyboard position both update immediately");
            input.pressed = false;
        }
    }

    function test_sliderNativeMapping(): void {
        const slider = createTemporaryObject(bareSliderFactory, this, {width: 300, height: 44});
        const before = findChild(slider, "sliderTrackBefore");
        const after = findChild(slider, "sliderTrackAfter");
        compare(String(before.color), String(Ui.Theme.accent));
        compare(String(after.color), String(Ui.Theme.selected));
        slider.forceActiveFocus();
        keyClick(Qt.Key_End);
        compare(slider.value, slider.to);
        compare(slider.handle.x, slider.availableWidth - slider.handle.width);
        keyClick(Qt.Key_Home);
        compare(slider.value, slider.from);
        edited.target = slider;
        edited.clear();
        mouseClick(slider, slider.width / 4, slider.height / 2);
        verify(slider.value > 20 && slider.value < 40, "native pointer mapping agrees with the painted direction");
        verify(edited.count > 0);
        const saved = slider.value;
        const count = edited.count;
        slider.enabled = false;
        slider.moveToBoundary(slider.to);
        mouseClick(slider);
        compare(slider.value, saved);
        compare(edited.count, count);
    }

    function test_segmentedSelectionFocusAndAccessibleGuards(): void {
        const control = createTemporaryObject(segmentsFactory, this);
        const first = findChild(control, "segment-first");
        const unavailable = findChild(control, "segment-second");
        const third = findChild(control, "segment-third");
        selection.target = control;
        selection.clear();
        control.forceActiveFocus();
        mouseMove(third, third.width / 2, third.height / 2);
        compare(control.value, "first", "hover cannot select");
        verify(findChild(first, "focusRing").visible);
        keyClick(Qt.Key_Right);
        compare(control.value, "third", "skip the unavailable option");
        compare(selection.count, 1);
        verify(!findChild(first, "focusRing").visible);
        verify(findChild(third, "focusRing").visible);
        compare(String(third.color), String(Ui.Theme.selected), "selection fill cannot lag behind foreground/focus");
        verify(third.Accessible.checked && third.Accessible.focused);
        compare(third.Accessible.role, Accessible.RadioButton);
        compare(third.Accessible.name, "Third");
        unavailable.Accessible.pressAction();
        compare(selection.count, 1);
        first.Accessible.pressAction();
        compare(control.value, "first");
        control.LayoutMirroring.enabled = true;
        tryVerify(() => first.x > third.x);
        keyClick(Qt.Key_Left);
        compare(control.value, "third", "mirrored arrow navigation follows the visual order");
        control.interactive = false;
        const count = selection.count;
        first.Accessible.pressAction();
        control.choose(0);
        keyClick(Qt.Key_Right);
        compare(selection.count, count);
        verify(control.activeFocus && findChild(third, "focusRing").visible);
        control.interactive = true;
        control.enabled = false;
        control.choose(0);
        first.Accessible.pressAction();
        compare(selection.count, count);
    }

}
