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

    function test_threeTabsAndKeyboardCycle() {
        const panel = makePanel();
        panel.width = 420;
        const controller = panel.controller;
        const page = findChild(panel, "batteryDetailPage");
        const tabs = findChild(panel, "batteryViewTabs");
        compare(tabs.tabs.length, 3);
        compare(controller.viewTab, "overview");
        const panes = [findChild(panel, "batteryOverviewPane"),
            findChild(panel, "batteryCarePane"), findChild(panel, "batteryPowerPane")];
        for (let index = 0; index < 3; ++index) {
            compare(controller.viewTab, tabs.tabs[index].value);
            compare(tabs.selectedValue, controller.viewTab);
            verify(tabs.tabs[index].icon.length > 0);
            for (let other = 0; other < 3; ++other)
                compare(panes[other].visible, index === other);
            tryCompare(page, "contentHeight", panes[index].height);
            compare(panes[index].width, page.width);
            compare(panes[index].mapToItem(page.contentItem, 0, 0).y, 0,
                "hidden tabs must not leave empty space in the active page");
            verify(controller.cycleViewTab());
        }
        compare(controller.viewTab, "overview", "cycle wraps to the first tab");
        controller.selectViewTab("invalid");
        compare(controller.viewTab, "overview", "ignore unknown tabs");
        tabs.selected("care");
        compare(controller.viewTab, "care");
    }

    function test_levelsLiveInPowerTabWithIndependentActions() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applyPowerProfile({ available: true, profiles: [{ name: "balanced" }, { name: "power-saver" }],
            battery_automation: { level: "low", status: "paused", profile: "power-saver" } });
        controller.applyBattery({ available: true, percentage: 20, policy: {
            warning_percent: 35, critical_percent: 10, notify_warning: false, notify_critical: true,
            warning_profile: "balanced", critical_profile: "power-saver", notify_when_full: false
        } });
        controller.selectViewTab("care");
        verify(!findChild(panel, "batteryLevelsCard").visible);
        verify(findChild(panel, "batteryChargeNotificationCard").visible);
        controller.selectViewTab("power");
        verify(findChild(panel, "batteryLevelsCard").visible);
        verify(!findChild(panel, "batteryChargeNotificationCard").visible);
        compare(findChild(panel, "batteryLowPoint").value, 35);
        compare(findChild(panel, "batteryCriticalPoint").value, 10);
        verify(!findChild(panel, "batteryLowNotify"));
        verify(!findChild(panel, "batteryCriticalNotify"));
        verify(!findChild(panel, "batteryLowEnabled").checked);
        verify(findChild(panel, "batteryCriticalEnabled").checked);
        findChild(panel, "batteryLowEnabled").activate();
        verify(controller.draftNotifyWarning);
        compare(controller.draftWarningProfile, "balanced");
        controller.settingsOperationFinished("alert");
        const profile = findChild(panel, "batteryLowProfile");
        compare(profile.value, "balanced");
        compare(profile.options.length, 3);
        verify(!profile.optionEnabled(2), "unavailable Performance cannot be selected");
        verify(findChild(panel, "batteryAutomationResume").visible);
        verify(findChild(panel, "batteryAutomationStatus").text.indexOf("paused") >= 0);
        panel.width = 420;
        verify(waitForRendering(panel));
        const page = findChild(panel, "batteryDetailPage");
        const card = findChild(panel, "batteryLevelsCard");
        verify(card.width <= page.width);
        const footer = findChild(panel, "batteryViewTabs");
        verify(page.mapToItem(panel, 0, page.height).y < footer.mapToItem(panel, 0, 0).y);
        controller.applyPowerProfile({ available: true, profiles: [],
            battery_automation: { level: "normal", status: "waiting", profile: "" } });
        verify(!findChild(panel, "batteryAutomationResume").visible);
        verify(!findChild(panel, "batteryAutomationStatus").visible);
        const saveStatus = findChild(panel, "batteryLevelsSaveStatus");
        verify(!saveStatus.visible, "routine applied status stays hidden");
        controller.alertOperationActive = true;
        verify(saveStatus.visible, "saving feedback remains available");
        controller.alertOperationActive = false;
        controller.alertSaveError = "Unable to save";
        verify(saveStatus.visible, "save errors remain visible");
        controller.applyPowerProfile({ available: true, profiles: [],
            battery_automation: { level: "low", status: "error", error: "Unable to switch profile" } });
        verify(findChild(panel, "batteryAutomationStatus").visible);
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
