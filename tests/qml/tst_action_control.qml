pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Ui as Ui
import Shelllist.Bar as Bar

TestCase {
    id: testCase
    name: "ActionControl"
    when: windowShown
    visible: true
    width: 200
    height: 100

    Component { id: button; Ui.ActionButton { label: "Button" } }
    Component { id: area; Ui.ActionArea { accessibleName: "Area" } }
    Component { id: tab; Ui.DetailsTab { label: "Tab" } }
    Component { id: toggle; Ui.ToggleRow { title: "Toggle" } }
    Component { id: toggleSwitch; Ui.ToggleSwitch {} }
    Component { id: bar; Bar.BarAction { text: "Bar" } }
    SignalSpy { id: clicks; signalName: "clicked" }
    SignalSpy { id: secondary; signalName: "secondaryTriggered" }

    function test_sharedActivation_data() {
        return [
            {tag: "button", factory: button}, {tag: "area", factory: area},
            {tag: "tab", factory: tab}, {tag: "toggle", factory: toggle},
            {tag: "switch", factory: toggleSwitch}, {tag: "bar", factory: bar}
        ];
    }
    function test_sharedActivation(data) {
        const control = createTemporaryObject(data.factory, testCase, {width: 160, height: 40});
        verify(control !== null);
        clicks.target = control;
        clicks.clear();
        control.forceActiveFocus();
        for (const key of [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space])
            keyClick(key);
        compare(clicks.count, 3);
        keyClick(Qt.Key_Right);
        compare(clicks.count, 3, "navigation is not activation");
        mouseClick(control, 80, 20);
        compare(clicks.count, 4, "pointer and keyboard share activation");
        control.Accessible.pressAction();
        compare(clicks.count, 5, "assistive press shares activation");
        const checkable = data.tag === "toggle" || data.tag === "switch";
        if (checkable)
            control.Accessible.toggleAction();
        const accepted = checkable ? 6 : 5;
        compare(clicks.count, accepted, "assistive toggle shares activation");
        control.interactive = false;
        verify(control.activeFocus, "becoming busy must retain focus");
        keyClick(Qt.Key_Space);
        mouseClick(control, 80, 20);
        control.activate();
        control.Accessible.pressAction();
        compare(clicks.count, accepted, "busy controls must not activate");
        control.interactive = true;
        control.enabled = false;
        control.activate();
        if (checkable)
            control.Accessible.toggleAction();
        compare(clicks.count, accepted, "disabled controls must not activate");
    }
    function test_barSecondaryIsDistinctFromPrimary() {
        const control = createTemporaryObject(bar, testCase, {width: 160, height: 40});
        clicks.target = control;
        secondary.target = control;
        clicks.clear();
        secondary.clear();
        mouseClick(control, 80, 20, Qt.RightButton);
        compare(secondary.count, 1);
        compare(clicks.count, 0);
        control.interactive = false;
        control.routeClick(Qt.RightButton);
        compare(secondary.count, 1);
    }
}
