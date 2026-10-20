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
            property bool initiallyActive: false
            Battery.BatteryController { id: controller; uiActive: panel.initiallyActive }
            Battery.BatteryContent { id: surface; controller: panel.controller }
        }
    }
    function init() { failOnWarning(/.*/); }
    function cleanup() {
        tests.width = 453;
        Ui.Theme.previewColorScheme = Qt.Unknown;
    }
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
        panel.controller.activateUiState("");
        tryVerify(() => panel.surface.detailsNavigation.browsing);
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
    function test_independentCriticalProtectionAndRecovery() {
        const panel = make("power");
        panel.controller.applySuspendPolicy({available: false, error: "Managed idle sleep unavailable", policy: panel.controller.suspendPolicyDraft});
        const toggle = browse(panel, "criticalBatteryEnabled");
        verify(toggle.interactive);
        verify(!findChild(panel, "lidCloseAction").interactive);
        keyClick(Qt.Key_Return);
        const modal = findChild(panel, "batterySafetyReview");
        tryVerify(() => modal.visible);
        keyClick(Qt.Key_R, Qt.AltModifier);
        keyClick(Qt.Key_C, Qt.AltModifier);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(panel.controller.viewTab, "power");
        compare(calls.length, 0);
        modal.focusAction("accept");
        keyClick(Qt.Key_Space);
        tryCompare(panel.controller, "suspendPolicySaving", true);
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setCriticalPolicy");
        panel.controller.suspendPolicyFailed("reply lost");
        verify(findChild(panel, "suspendPolicyRetry").enabled, "critical-only retry is independent of managed sleep");
        wait(0);
        compare(calls.length, 1, "failed settings are not replayed automatically");
        panel.surface.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(calls.length, 2);
        compare(calls[1].method, "powerSleep.setCriticalPolicy");
        panel.controller.suspendPolicyFinished();
        panel.controller.applySuspendPolicy({available: false, policy: panel.controller.suspendPolicyDraft, critical_battery: {phase: "countdown", remaining_seconds: 42}});
        tryVerify(() => findChild(panel, "feedbackText").text.includes("42"));
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(calls.length, 3);
        compare(calls[2].method, "powerSleep.cancelCritical");
        verify(!findChild(panel, "criticalBatteryCancel").enabled, "pending cancellation cannot be repeated");
    }
    function test_linkedSleepSavesOneDerivedPairAndRetainsRetry() {
        const panel = make("power");
        const suspend = browse(panel, "suspendDelay-battery");
        const hibernate = findChild(panel, "hibernateDelay-battery");
        compare(suspend.value, 30); compare(hibernate.value, 60);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right);
        compare(suspend.value, 45); compare(hibernate.value, 60);
        compare(panel.controller.suspendPolicyDraft.battery.sleep_minutes, 30);
        compare(panel.controller.suspendPolicyDraft.battery.hibernate_minutes, 30);
        compare(calls.length, 0, "neither stored duration changes before save");
        keyClick(Qt.Key_Escape); compare(suspend.value, 30);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Tab);
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setPolicy");
        compare(calls[0].params.battery.sleep_minutes, 45);
        compare(calls[0].params.battery.hibernate_minutes, 15);
        verify(panel.controller.suspendPolicySaving);
        verify(!suspend.interactive && !hibernate.interactive);
        panel.controller.suspendPolicyFailed("not acknowledged");
        wait(0); compare(calls.length, 1, "failure does not replay a pair");
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(calls.length, 2);
        compare(calls[1].params.battery.hibernate_minutes, 15);
        panel.controller.suspendPolicyFinished();
        browse(panel, "hibernateDelay-battery");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        compare(calls.length, 3);
        compare(calls[2].params.battery.sleep_minutes, 45);
        compare(calls[2].params.battery.hibernate_minutes, 45, "90 total minus 45 idle");
    }
}
