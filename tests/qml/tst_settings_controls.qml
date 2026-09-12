import QtQuick
import QtTest
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
        id: toggleFactory
        Ui.ToggleRow {
            width: 296
            height: implicitHeight
            title: "Multipoint"
            subtitle: "Authenticated configurable Fast Pair multipoint is unavailable"
            interactive: false
        }
    }
    function test_longDisabledReasonFitsNarrowToggle(): void {
        const row = createTemporaryObject(toggleFactory, this);
        verify(waitForRendering(row));
        const subtitle = findChild(row, "toggleSubtitle");
        verify(subtitle.truncated);
        verify(subtitle.mapToItem(row, subtitle.width, 0).x < row.width - 42);
        compare(row.Accessible.name, row.title + ". " + row.subtitle);
    }

    SignalSpy {
        id: edited
        signalName: "edited"
    }
    SignalSpy {
        id: finished
        signalName: "editingFinished"
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
