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
        compare(tabs.options.length, 3);
        compare(controller.viewTab, "overview");
        const panes = [findChild(panel, "batteryOverviewPane"),
            findChild(panel, "batteryCarePane"), findChild(panel, "batteryPowerPane")];
        for (let index = 0; index < 3; ++index) {
            compare(controller.viewTab, tabs.options[index].value);
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
