import QtQuick
import QtQuick.Layouts
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
        id: disclosureFactory
        Ui.DisclosureSection {
            objectName: "advanced"
            width: 420
            title: "Advanced settings"
            Ui.DetailColumnCard {
                objectName: "tonalCard"
                Layout.fillWidth: true
                title: "Settings"
                Ui.SettingRow {
                    objectName: "settingRow"
                    title: "A setting with a long descriptive name"
                    subtitle: "Supporting information remains visible when the label wraps."
                    Ui.TextField {
                        objectName: "retainedDraft"
                        Layout.preferredWidth: 116
                        text: "draft"
                    }
                }
            }
        }
    }
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
    SignalSpy {
        id: finished
        signalName: "editingFinished"
    }

    function init(): void {
        failOnWarning(/.*/);
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: "false" };
    }
    function cleanup(): void {
        edited.target = null;
        finished.target = null;
        selection.target = null;
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = Qt.Unknown;
    }
    function test_tonalDisclosureRetainsDraftsAndRevealsAttention(): void {
        const disclosure = createTemporaryObject(disclosureFactory, this);
        const toggle = findChild(disclosure, "advancedToggle");
        const card = findChild(disclosure, "tonalCard");
        const row = findChild(disclosure, "settingRow");
        const draft = findChild(disclosure, "retainedDraft");
        verify(!draft.visible);
        verify(toggle.height >= 56);
        compare(toggle.border.width, 0);
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(disclosure.open && draft.visible);
        draft.text = "unsaved";
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(!draft.visible);
        disclosure.attention = true;
        verify(disclosure.open && draft.visible);
        toggle.Accessible.pressAction();
        verify(disclosure.open);
        compare(draft.text, "unsaved");
        for (const scheme of [Qt.Light, Qt.Dark]) {
            Ui.Theme.previewColorScheme = scheme;
            compare(card.border.width, 0);
            compare(card.color.a, 1);
            compare(String(card.color), String(Ui.Theme.surface));
            verify(String(card.color) !== String(Ui.Theme.window));
        }
        disclosure.width = 320;
        wait(0);
        verify(row.height >= 56);
        verify(draft.mapToItem(row, draft.width, 0).x <= row.width);
        verify(card.height >= row.height);
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

    function test_sliderNativeMapping_data() {
        return [
            { tag: "horizontal", vertical: false, rtl: false },
            { tag: "mirrored", vertical: false, rtl: true },
            { tag: "vertical", vertical: true, rtl: false }
        ];
    }
    function test_sliderNativeMapping(data): void {
        const slider = createTemporaryObject(bareSliderFactory, this, {
            width: data.vertical ? 44 : 300,
            height: data.vertical ? 180 : 44,
            orientation: data.vertical ? Qt.Vertical : Qt.Horizontal
        });
        slider.LayoutMirroring.enabled = data.rtl;
        const before = findChild(slider, "sliderTrackBefore");
        const after = findChild(slider, "sliderTrackAfter");
        const forward = !data.vertical && !data.rtl;
        compare(String(before.color), String(forward ? Ui.Theme.accent : Ui.Theme.selected));
        compare(String(after.color), String(forward ? Ui.Theme.selected : Ui.Theme.accent));
        slider.forceActiveFocus();
        keyClick(Qt.Key_End);
        compare(slider.value, slider.to);
        const position = data.vertical ? slider.handle.y : slider.handle.x;
        const extent = data.vertical ? slider.availableHeight - slider.handle.height : slider.availableWidth - slider.handle.width;
        compare(position, forward ? extent : 0);
        keyClick(Qt.Key_Home);
        compare(slider.value, slider.from);
        edited.target = slider;
        edited.clear();
        const quarter = forward ? 0.25 : 0.75;
        mouseClick(slider, data.vertical ? slider.width / 2 : slider.width * quarter,
                   data.vertical ? slider.height * quarter : slider.height / 2);
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

    function test_percentageKeyboardAndAccessibleLabel(): void {
        const slider = createTemporaryObject(sliderFactory, this);
        const input = findChild(slider, "labeledValueSliderInput");
        verify(input !== null);
        compare(input.Accessible.name, "Low battery");
        compare(input.Accessible.description, "20%");
        edited.target = slider;
        edited.clear();
        finished.target = slider;
        finished.clear();
        input.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(slider.value, 21);
        compare(slider.valueText, "21%");
        compare(edited.count, 1);
        compare(edited.signalArguments[0][0], true);
        compare(finished.count, 1);
        slider.to = 99;
        keyClick(Qt.Key_End);
        compare(slider.value, 99);
        compare(finished.count, 2);
        keyClick(Qt.Key_Home);
        compare(slider.value, 0);
        compare(finished.count, 3);
        keyClick(Qt.Key_End);
        slider.enabled = false;
        keyClick(Qt.Key_Left);
        compare(slider.value, 99);
        edited.target = null;
        finished.target = null;
    }
}
