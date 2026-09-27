pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Battery as Battery

TestCase {
    id: testCase
    name: "BatteryTabs"
    when: windowShown
    visible: true
    width: 560
    height: 760

    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            Battery.BatteryController {
                id: controller
            }
            Battery.BatteryContent {
                controller: panel.controller
            }
        }
    }

    Component {
        id: profileSpyComponent
        SignalSpy {
            signalName: "selected"
        }
    }

    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_profileSelectionSupportsKeyboardAndAccessibility() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applyPowerProfile({
            available: true,
            profile: "balanced",
            profiles: [
                {
                    name: "power-saver"
                },
                {
                    name: "balanced"
                },
                {
                    name: "performance"
                }
            ],
            battery_automation: {
                status: "waiting"
            }
        });
        controller.selectViewTab("power");
        const selector = findChild(panel, "batteryLowProfile");
        const toggle = findChild(panel, "batteryLowEnabled");
        const point = findChild(panel, "batteryLowPoint");
        for (const width of [420, 560]) {
            panel.width = width;
            verify(waitForRendering(panel));
            const card = findChild(panel, "batteryLevelsCard");
            verify(selector.mapToItem(card, selector.width, 0).x <= card.width - card.contentPadding + 1, "profile selector stays inside the card: " + selector.mapToItem(card, selector.width, 0).x + " <= " + (card.width - card.contentPadding));
        }
        controller.applyPowerProfile({
            available: true,
            profile: "balanced",
            profiles: [
                {
                    name: "power-saver"
                },
                {
                    name: "balanced"
                }
            ],
            battery_automation: {
                status: "waiting"
            }
        });
        verify(waitForRendering(panel));
        const saver = findChild(selector, "profileOption-power-saver");
        const balanced = findChild(selector, "profileOption-balanced");
        const performance = findChild(selector, "profileOption-performance");
        for (const button of [saver, balanced, performance]) {
            verify(button.Accessible.name.indexOf("Low battery power profile") >= 0);
            compare(button.Accessible.role, Accessible.RadioButton);
        }
        verify(saver.Accessible.checked);
        verify(!performance.enabled);
        const spy = createTemporaryObject(profileSpyComponent, testCase, {
            target: selector
        });
        mouseClick(balanced);
        compare(spy.count, 1);
        compare(controller.alertDraft.warning_profile, "balanced");
        verify(balanced.Accessible.checked);
        balanced.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(spy.count, 1, "keyboard skips unavailable Performance");
        keyClick(Qt.Key_Left);
        compare(controller.alertDraft.warning_profile, "power-saver");
        verify(saver.activeFocus);
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(controller.alertDraft.warning_profile, "keep-current");
        verify(!toggle.checked);
        verify(!controller.alertDraft.notify_warning);
        verify(controller.alertDraft.notify_critical);
        verify(!point.enabled);
        verify(!saver.enabled);
        verify(findChild(panel, "batteryCriticalEnabled").checked);
        keyClick(Qt.Key_Space);
        compare(controller.alertDraft.warning_profile, "power-saver");
        verify(controller.alertDraft.notify_warning);
        verify(point.enabled);
        verify(saver.enabled);
        controller.actionInFlight = true;
        const count = spy.count;
        mouseClick(balanced);
        selector.move(1);
        compare(spy.count, count, "busy controls cannot dispatch profile changes");
    }

}
