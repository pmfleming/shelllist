pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Battery as Battery

DaemonTestCase {
    id: testCase
    name: "BatteryTabs"
    when: windowShown
    visible: true
    width: 560
    height: 760

    function init(): void { failOnWarning(/.*/); }

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

    function test_panelTabHintsStayAtTheBottomBar() {
        const panel = makePanel();
        panel.controller.uiActive = true;
        const tabs = findChild(panel, "batteryViewTabs");
        const badge = findChild(tabs, "tabShortcutBadge");
        verify(badge !== null);
        verify(!badge.visible);
        tabs.forceActiveFocus();
        keyPress(Qt.Key_Control);
        tryCompare(badge, "visible", true);
        compare(badge.text, "Ctrl+Tab");
        const before = panel.controller.viewTab;
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        verify(panel.controller.viewTab !== before);
        keyRelease(Qt.Key_Control);
        verify(!badge.visible);
        panel.controller.uiActive = false;
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
        findChild(panel, "batteryAutomationSection").expanded = true;
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
        const saver = findChild(selector, "segment-power-saver");
        const balanced = findChild(selector, "segment-balanced");
        const performance = findChild(selector, "segment-performance");
        for (const button of [saver, balanced, performance]) {
            verify(button.Accessible.name.length > 0);
            compare(selector.Accessible.name, "Low battery power profile");
            compare(button.Accessible.role, Accessible.RadioButton);
        }
        verify(saver.Accessible.checked);
        verify(!performance.enabled);
        const spy = createTemporaryObject(profileSpyComponent, testCase, {
            target: selector
        });
        findChild(panel, "batteryDetailPage").revealItem(selector);
        wait(0);
        mouseClick(balanced);
        compare(spy.count, 1);
        compare(controller.alertDraft.warning_profile, "balanced");
        verify(balanced.Accessible.checked);
        selector.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(spy.count, 1, "keyboard skips unavailable Performance");
        keyClick(Qt.Key_Left);
        compare(controller.alertDraft.warning_profile, "power-saver");
        verify(selector.activeFocus);
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
