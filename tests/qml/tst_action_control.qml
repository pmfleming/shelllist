import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "ActionControl"
    when: windowShown
    visible: true
    width: 200
    height: 100
    Component {
        id: toggleSwitch
        Ui.ToggleSwitch { width: 160; height: 40 }
    }
    SignalSpy {
        id: clicks
        signalName: "clicked"
    }
    // Representative checkable control covers both assistive activation routes.
    // Header, tray and recovery tests own their actual command routing.
    function test_sharedActivationAndBusyGuards() {
        const control = createTemporaryObject(toggleSwitch, testCase);
        clicks.target = control;
        control.forceActiveFocus();
        for (const key of [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space])
            keyClick(key);
        compare(clicks.count, 3);
        keyClick(Qt.Key_Right);
        compare(clicks.count, 3, "navigation is not activation");
        mouseClick(control, 80, 20);
        control.Accessible.pressAction();
        control.Accessible.toggleAction();
        compare(clicks.count, 6, "pointer and assistive commands share activation");
        control.interactive = false;
        verify(control.activeFocus, "becoming busy must retain focus");
        keyClick(Qt.Key_Space);
        mouseClick(control, 80, 20);
        control.activate();
        control.Accessible.pressAction();
        compare(clicks.count, 6, "busy controls must not activate");
        control.interactive = true;
        control.enabled = false;
        control.activate();
        control.Accessible.toggleAction();
        compare(clicks.count, 6, "disabled controls must not activate");
    }
}
