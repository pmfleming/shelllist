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
    SignalSpy {
        id: edited
        signalName: "edited"
    }
    SignalSpy {
        id: finished
        signalName: "editingFinished"
    }

    function test_sliderMotionPolicy(): void {
        try {
            Quickshell.environment = {
                SHELLLIST_NO_ANIMATIONS: "false"
            };
            const slider = createTemporaryObject(sliderFactory, this);
            const input = findChild(slider, "labeledValueSliderInput");
            waitForRendering(input);
            const start = input.handle.x;
            input.value = input.to;
            compare(input.handle.x, start, "keyboard changes animate rather than jump");
            tryVerify(() => input.handle.x > start);
            input.pressed = true;
            input.value = input.from;
            compare(input.handle.x, input.leftPadding, "dragging bypasses animation");
            input.pressed = false;
            Quickshell.environment = {
                SHELLLIST_NO_ANIMATIONS: "true"
            };
            input.value = input.to;
            compare(input.handle.x, input.leftPadding + input.availableWidth - input.handle.width);
        } finally {
            Quickshell.environment = ({});
        }
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
