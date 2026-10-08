pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Battery as Battery
import Shelllist.Ui as Ui

DaemonTestCase {
    id: tests
    name: "BatteryPresentation"
    when: windowShown
    visible: true
    width: 453
    height: 900

    Component {
        id: factory
        Item {
            id: panel
            width: tests.width
            height: tests.height
            property alias controller: controller
            property alias surface: surface
            Battery.BatteryController { id: controller; uiActive: true }
            Battery.BatteryContent { id: surface; controller: panel.controller }
        }
    }
    function init() { failOnWarning(/.*/); }
    function battery(id = "BAT0", once = false) {
        return {available: true, percentage: 87, plugged: true, charging: true,
            power_available: true, power_watts: 8.4,
            forecast: {seconds: 720, target: 90, limit: 90},
            devices: [{id: id, health_percent: 94, cycles: 186,
                protection: {supported: true, managed: true, enabled: true,
                    desired_enabled: true, desired_start_percent: 85, desired_end_percent: 90,
                    start_percent: 85, end_percent: 90, thresholds_verified: true,
                    charge_once_active: once, available_behaviours: ["inhibit-charge", "force-discharge"]}}]};
    }
    function make(tab = "overview") {
        const panel = createTemporaryObject(factory, tests);
        verify(panel !== null);
        wait(0);
        panel.controller.applyPowerProfile({available: true, profile: "balanced",
            profiles: [{name: "power-saver"}, {name: "balanced"}, {name: "performance"}]});
        panel.controller.applyBattery(battery());
        panel.controller.applySuspendPolicy({available: true, hibernate_available: true,
            lid: {available: true},
            policy: {lid_action: "suspend", same_profile: true,
                battery: {sleep_minutes: 30, hibernate_minutes: 30},
                plugged: {sleep_minutes: 30, hibernate_minutes: 30},
                critical_battery: {enabled: false, percent: 5, grace_seconds: 60}}});
        panel.controller.selectViewTab(tab);
        verify(waitForRendering(panel));
        panel.surface.detailsNavigation.focusContent(true);
        wait(0);
        calls = [];
        return panel;
    }
    function browse(panel, name) {
        const target = findChild(panel, name);
        verify(target !== null);
        for (let i = 0; i < 24 && panel.surface.detailsNavigation.currentTarget !== target; i++) keyClick(Qt.Key_Tab);
        compare(panel.surface.detailsNavigation.currentTarget, target);
        return target;
    }
    function test_compactControlsFitNarrowPanel() {
        const originalWidth = tests.width;
        tests.width = 320;
        try {
            const panel = make();
            const mode = findChild(panel, "batteryPowerModeProfile");
            const card = findChild(panel, "powerModeCard");
            const position = mode.mapToItem(card, 0, 0);
            verify(position.x >= 0 && position.x + mode.width <= card.width);
            panel.controller.selectViewTab("care");
            verify(waitForRendering(panel));
            const actions = findChild(panel, "batteryChargingActions");
            compare(actions.buttons.length, 3);
            for (const button of actions.buttons) {
                const p = button.mapToItem(actions, 0, 0);
                verify(p.x >= 0 && p.x + button.width <= actions.width + 1);
                verify(button.width >= Ui.Theme.minimumSecondaryActionHeight);
            }
        } finally {
            tests.width = originalWidth;
        }
    }
    function test_modeIsFirstCircularAndDeferred() {
        const panel = make();
        const mode = findChild(panel, "batteryPowerModeProfile");
        verify(mode.circular && mode.iconOnly);
        compare(panel.surface.detailsNavigation.currentTarget, mode);
        const modeCard = findChild(panel, "powerModeCard");
        const historyCard = findChild(panel, "batteryHistoryCard");
        verify(modeCard.y + modeCard.height <= historyCard.y);
        const balanced = findChild(mode, "segment-balanced");
        compare(balanced.width, balanced.height);
        compare(balanced.Accessible.name, "Balanced");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(mode.displayedValue, "performance");
        compare(mode.value, "balanced");
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(mode.displayedValue, "balanced");
        const saver = findChild(mode, "segment-power-saver");
        mouseClick(saver, saver.width / 2, saver.height / 2);
        compare(mode.displayedValue, "power-saver");
        compare(calls.length, 0, "pointer choice is still a local draft");
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].method, "powerProfile.set");
        compare(calls[0].params.profile, "power-saver");
        compare(mode.value, "balanced", "save is not acknowledgement");
        verify(!mode.interactive);
        panel.controller.operationFinished(calls[0].id);
        panel.controller.applyPowerProfile({available: true, profile: "power-saver", profiles: [{name: "power-saver"}, {name: "balanced"}, {name: "performance"}]});
        compare(mode.value, "power-saver");
    }
    function test_fieldTraversalAndIconOnlyTabs() {
        const panel = make();
        const nav = panel.surface.detailsNavigation;
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(nav.currentTarget.objectName, "batteryEnergyPeriod");
        keyClick(Qt.Key_Tab);
        compare(nav.currentTarget.objectName, "batteryPowerModeProfile");
        const tabBar = findChild(panel, "batteryViewTabs");
        const tabs = [];
        function collect(item) { if (item instanceof Ui.DetailsTab) tabs.push(item); for (const child of item.children) collect(child); }
        collect(tabBar);
        compare(tabs.length, 3);
        for (const tab of tabs) {
            verify(tab.icon.length > 0 && tab.Accessible.name.length > 0);
            const glyph = findChild(tab, "controlIcon");
            verify(glyph !== null);
            compare(glyph.parent.label, "");
        }
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(panel.controller.viewTab, "care");
    }
    function test_combinedChargingTargetsAndDeferredThresholds() {
        const panel = make("care");
        const notify = findChild(panel, "batteryChargeNotificationToggle");
        const card = findChild(panel, "batteryProtectionCard");
        verify(notify.mapToItem(card, 0, 0).y >= 0);
        verify(findChild(panel, "batteryChargeNotificationCard") === null);
        compare(notify.title, "90%");
        verify(notify.Accessible.name.includes("90"));
        verify(!findChild(panel, "batteryThresholdSaveStatus").visible);
        const start = browse(panel, "batteryResumeCharging");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Left);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(start.value, 85);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Tab);
        tryVerify(() => calls.some(c => c.method === "battery.setThresholds"));
        const write = calls.find(c => c.method === "battery.setThresholds");
        compare(write.params.battery_id, "BAT0");
        verify(write.params.start_percent < 85);
        panel.controller.applyBattery(battery("BAT0", true));
        compare(notify.title, "100%");
        panel.controller.thresholdSaveError = "firmware rejected range";
        verify(findChild(panel, "batteryThresholdSaveStatus").visible);
    }
    function test_calibrationReviewBlocksCommandsAndRetargeting() {
        const panel = make("care");
        const modal = findChild(panel, "batterySafetyReview");
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => modal.visible);
        verify(panel.controller.navigationBlocked);
        compare(calls.length, 0);
        keyClick(Qt.Key_O, Qt.AltModifier);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(calls.length, 0);
        compare(panel.controller.viewTab, "care");
        keyClick(Qt.Key_Escape);
        verify(!modal.visible);
        compare(calls.length, 0);
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => modal.visible);
        panel.controller.applyBattery(battery("BAT1"));
        verify(!modal.visible, "battery replacement cancels, never retargets confirmation");
        calls = [];
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => modal.visible);
        wait(0);
        modal.focusAction("accept");
        keyClick(Qt.Key_Space);
        tryVerify(() => calls.some(c => c.method === "battery.startCalibration"));
        const write = calls.find(c => c.method === "battery.startCalibration");
        compare(write.params.battery_id, "BAT1");
    }
    function test_criticalReviewAndUnavailableDiagnostic() {
        const panel = make("power");
        const critical = browse(panel, "criticalBatteryEnabled");
        keyClick(Qt.Key_Return);
        const modal = findChild(panel, "batterySafetyReview");
        tryVerify(() => modal.visible);
        verify(modal.detail.includes("one automatic power manager"));
        verify(!critical.checked);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        verify(!critical.checked);
        browse(panel, "criticalBatteryEnabled");
        keyClick(Qt.Key_Return);
        tryVerify(() => modal.visible);
        const accept = findChild(modal, "detailAction:accept");
        verify(accept !== null);
        mouseClick(accept, accept.width / 2, accept.height / 2);
        tryVerify(() => calls.some(c => c.method === "powerSleep.setCriticalPolicy"));
        const write = calls.find(c => c.method === "powerSleep.setCriticalPolicy");
        compare(write.params.enabled, true);
        panel.controller.applySuspendPolicy({available: false, error: "nested or inline hypridle listeners are not supported", policy: panel.controller.suspendPolicyDraft});
        compare(findChild(panel, "suspendPolicyStatus").text, "Automatic sleep unavailable");
        verify(!findChild(panel, "lidCloseAction").interactive);
        const details = findChild(panel, "suspendPolicyDetails");
        const page = findChild(panel, "batteryDetailPage");
        page.contentY = page.contentHeight - page.height;
        verify(waitForRendering(panel));
        mouseClick(details, details.width / 2, details.height / 2);
        verify(findChild(panel, "suspendPolicyDiagnostic").visible);
        verify(findChild(panel, "suspendPolicyDiagnostic").text.includes("nested or inline"));
    }
}
