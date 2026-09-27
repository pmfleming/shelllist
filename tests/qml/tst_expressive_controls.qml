pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "ExpressiveControls"
    when: windowShown
    visible: true
    width: 400
    height: 180

    Component {
        id: fixture
        Item {
            width: 400
            height: 180
            property alias button: button
            property alias other: other
            property alias toggle: toggle
            Ui.ActionButton {
                id: button
                width: 140
                label: "Action"
                tone: "accent"
            }
            Ui.ActionButton {
                id: other
                x: 160
                width: 140
                label: "Other"
            }
            Ui.ToggleSwitch {
                id: toggle
                y: 70
                accessibleName: "Preview setting"
                onToggled: function (value) { checked = value; }
            }
        }
    }
    SignalSpy {
        id: clicks
        signalName: "clicked"
    }

    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: "false" };
        verify(!Ui.Theme.noAnimations);
    }
    function cleanup() {
        clicks.target = null;
        Quickshell.environment = ({});
    }
    function noMotion(value) {
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: String(value) };
        compare(Ui.Theme.noAnimations, value);
    }

    function test_pressMorphNeverDelaysFocusOrActivation() {
        const scene = createTemporaryObject(fixture, testCase);
        const button = scene.button;
        clicks.target = button;
        clicks.clear();
        const width = button.width;
        const height = button.height;
        const restingRadius = button.radius;
        const ring = findChild(button, "focusRing");
        mousePress(button, width / 2, height / 2);
        verify(button.pressed && ring.visible);
        compare(clicks.count, 0);
        tryVerify(() => button.radius < restingRadius);
        compare(button.width, width);
        compare(button.height, height);
        mouseRelease(button, width / 2, height / 2);
        compare(clicks.count, 1);
        keyPress(Qt.Key_Space);
        compare(clicks.count, 2, "activation is immediate, not a spring completion callback");
        verify(button.pressed);
        scene.other.forceActiveFocus();
        verify(!button.pressed && !ring.visible);
        verify(findChild(scene.other, "focusRing").visible);
        keyRelease(Qt.Key_Space);
        button.forceActiveFocus();
        keyPress(Qt.Key_Return);
        compare(clicks.count, 3);
        button.interactive = false;
        verify(!button.pressed && button.activeFocus && ring.visible);
        keyRelease(Qt.Key_Return);
        compare(clicks.count, 3);
        noMotion(true);
        compare(button.radius, restingRadius, "changing policy stops an in-flight spring immediately");
        wait(50);
        compare(button.radius, restingRadius);
        button.interactive = true;
        noMotion(false);
        keyPress(Qt.Key_Space);
        tryVerify(() => button.radius < restingRadius, 1000, "motion still responds after policy changes");
        keyRelease(Qt.Key_Space);
        compare(clicks.count, 4);
        tryCompare(button, "radius", restingRadius);
    }

    function test_switchRetargetsWithoutDelayingCheckedState() {
        const scene = createTemporaryObject(fixture, testCase);
        const toggle = scene.toggle;
        const track = findChild(toggle, "toggleTrack");
        const handle = findChild(toggle, "toggleHandle");
        const offX = handle.x;
        const offWidth = handle.width;
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(toggle.checked && toggle.Accessible.checked);
        verify(findChild(toggle, "focusRing").visible);
        wait(25);
        keyClick(Qt.Key_Space);
        verify(!toggle.checked && !toggle.Accessible.checked);
        wait(25);
        keyClick(Qt.Key_Space);
        verify(toggle.checked);
        noMotion(true);
        compare(handle.x + handle.width / 2, track.width - track.height / 2);
        verify(handle.width > offWidth);
        compare(String(handle.color), String(Ui.Theme.accentText));
        keyClick(Qt.Key_Space);
        compare(handle.x, offX);
        compare(handle.width, offWidth);
        compare(String(handle.color), String(Ui.Theme.controlBorder));
        noMotion(false);
        wait(60);
        compare(handle.x, offX, "an old spring must not resume after motion is re-enabled");
        toggle.interactive = false;
        mouseClick(toggle);
        keyClick(Qt.Key_Space);
        verify(!toggle.checked && !toggle.keyboardPressed);
        verify(toggle.activeFocus);
    }
}
