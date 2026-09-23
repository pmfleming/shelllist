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
            Battery.BatteryController { id: controller }
            Battery.BatteryContent { controller: panel.controller }
        }
    }

    Component {
        id: profileSpyComponent
        SignalSpy { signalName: "selected" }
    }

    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        verify(waitForRendering(panel));
        return panel;
    }

    function device(id, health, end) {
        return { id: id, health_percent: health, cycles: 120,
            energy_now_wh: 30, energy_full_wh: 48, energy_full_design_wh: 60,
            protection: { supported: true, enabled: true, desired_enabled: true,
                desired_start_percent: end - 5, desired_end_percent: end,
                start_percent: end - 5, end_percent: end } };
    }

    function test_chargeNotificationIsFirstAndTracksChargeTarget() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.selectViewTab("care");
        const card = findChild(panel, "batteryChargeNotificationCard");
        const toggle = findChild(card, "batteryChargeNotificationToggle");
        const status = findChild(card, "batteryChargeNotificationSaveStatus");
        const care = findChild(panel, "batteryCarePane");
        for (const scenario of [
            { enabled: true, end: 80, once: false, title: "Notify at charge limit (80%)" },
            { enabled: true, end: 85, once: false, title: "Notify at charge limit (85%)" },
            { enabled: true, end: 85, once: true, title: "Notify at 100%" },
            { enabled: false, end: 85, once: false, title: "Notify at 100%" },
            { enabled: true, end: 100, once: false, title: "Notify at 100%" },
            { enabled: true, end: null, once: false, title: "Notify at 100%" }
        ]) {
            const limited = device("BAT0", 80, 80);
            limited.protection.enabled = scenario.enabled;
            limited.protection.end_percent = scenario.end;
            limited.protection.charge_once_active = scenario.once;
            controller.applyBattery({ available: true, plugged: true, devices: [limited, device("BAT1", 90, 85)] });
            verify(waitForRendering(panel));
            compare(card.mapToItem(care, 0, 0).y, 0, "notification is first, even with a device selector");
            compare(toggle.title, scenario.title);
            compare(toggle.subtitle, "");
            verify(!findChild(toggle, "toggleSubtitle").visible);
            verify(!status.visible, "routine applied status stays hidden");
        }
        controller.applyBattery({ available: true, devices: [] });
        compare(toggle.title, "Notify at 100%");
        toggle.activate();
        verify(!controller.draftNotifyWhenFull);
        controller.settingsOperationFinished("alert");
        controller.actionInFlight = true;
        verify(!toggle.interactive);
        controller.alertOperationActive = true;
        verify(status.visible, "saving feedback remains available");
        controller.alertOperationActive = false;
        controller.alertSaveError = "Unable to save";
        verify(status.visible, "save errors remain visible");
    }

    function test_profileSelectionSupportsKeyboardAndAccessibility() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applyPowerProfile({ available: true, profile: "balanced",
            profiles: [{ name: "power-saver" }, { name: "balanced" }, { name: "performance" }],
            battery_automation: { status: "waiting" } });
        controller.selectViewTab("power");
        const selector = findChild(panel, "batteryLowProfile");
        const toggle = findChild(panel, "batteryLowEnabled");
        const point = findChild(panel, "batteryLowPoint");
        for (const width of [420, 560]) {
            panel.width = width;
            verify(waitForRendering(panel));
            const card = findChild(panel, "batteryLevelsCard");
            verify(selector.mapToItem(card, selector.width, 0).x <= card.width - card.contentPadding + 1,
                "profile selector stays inside the card: " + selector.mapToItem(card, selector.width, 0).x + " <= " + (card.width - card.contentPadding));
        }
        controller.applyPowerProfile({ available: true, profile: "balanced",
            profiles: [{ name: "power-saver" }, { name: "balanced" }],
            battery_automation: { status: "waiting" } });
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
        const spy = createTemporaryObject(profileSpyComponent, testCase, { target: selector });
        mouseClick(balanced);
        compare(spy.count, 1);
        compare(controller.draftWarningProfile, "balanced");
        verify(balanced.Accessible.checked);
        balanced.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(spy.count, 1, "keyboard skips unavailable Performance");
        keyClick(Qt.Key_Left);
        compare(controller.draftWarningProfile, "power-saver");
        verify(saver.activeFocus);
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(controller.draftWarningProfile, "keep-current");
        verify(!toggle.checked);
        verify(!controller.draftNotifyWarning);
        verify(controller.draftNotifyCritical);
        verify(!point.enabled);
        verify(!saver.enabled);
        verify(findChild(panel, "batteryCriticalEnabled").checked);
        keyClick(Qt.Key_Space);
        compare(controller.draftWarningProfile, "power-saver");
        verify(controller.draftNotifyWarning);
        verify(point.enabled);
        verify(saver.enabled);
        controller.actionInFlight = true;
        const count = spy.count;
        mouseClick(balanced);
        selector.move(1);
        compare(spy.count, count, "busy controls cannot dispatch profile changes");
    }

    function test_deviceSelectionStaysWithCareSettings() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applyBattery({ available: true, percentage: 60, devices: [device("BAT0", 80, 80)] });
        controller.selectViewTab("care");
        const card = findChild(panel, "batteryDeviceCard");
        const selector = findChild(panel, "batteryDeviceSelector");
        const health = findChild(panel, "batteryHealthCard");
        verify(!card.visible, "single-battery systems need no device selector");
        controller.applyBattery({ available: true, percentage: 60,
            devices: [device("BAT0", 80, 80), device("BAT1", 90, 85)] });
        verify(card.visible);
        verify(card.height >= 100, "the selector must not collapse to a boolean height");
        selector.selected("BAT1");
        compare(controller.primaryDevice.id, "BAT1");
        compare(controller.draftEndPercent, 85);
        compare(health.entries[0].value, "90%");
        controller.selectViewTab("overview");
        controller.selectViewTab("care");
        compare(selector.value, "BAT1", "tab changes retain device selection");
        controller.applyBattery({ available: true, percentage: 60, devices: [device("BAT0", 80, 80)] });
        verify(!card.visible);
        compare(controller.primaryDevice.id, "BAT0");
        compare(health.entries[0].value, "80%");
    }
}
