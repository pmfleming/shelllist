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
    function test_activeBeforeViewIsVisible() {
        // Cold entry: activation/host focus signals can predate view readiness.
        const panel = createTemporaryObject(factory, tests, {visible: false, initiallyActive: true});
        panel.controller.applyPowerProfile({available: true, profile: "balanced", profiles: [{name: "balanced"}]});
        wait(0);
        verify(panel.surface.pendingFocus);
        panel.visible = true;
        tryVerify(() => panel.surface.detailsNavigation.browsing);
        tryCompare(panel.surface.detailsNavigation, "currentTarget", findChild(panel, "batteryPowerModeProfile"));
        keyClick(Qt.Key_Return);
        verify(panel.surface.detailsNavigation.editing, "Enter works without an initial Tab");
        keyClick(Qt.Key_Escape);
    }
    function test_combinedChargingTargetsAndDeferredThresholds() {
        const panel = make("care");
        const notify = findChild(panel, "batteryChargeNotificationToggle");
        compare(notify.title, "90%");
        verify(notify.Accessible.name.includes("90"));
        verify(!findChild(panel, "batteryThresholdSaveStatus").active);
        const start = browse(panel, "batteryResumeCharging");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Left);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(start.value, 85);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Tab);
        tryVerify(() => calls.some(c => c.method === "battery.operation.start" && c.params.method === "battery.setThresholds"));
        const write = calls.find(c => c.method === "battery.operation.start");
        compare(write.params.params.battery_id, "BAT0");
        verify(write.params.params.start_percent < 85);
        panel.controller.applyBattery(battery("BAT0", true));
        compare(notify.title, "100%");
        panel.controller.thresholdSaveError = "firmware rejected range";
        verify(findChild(panel, "batteryThresholdSaveStatus").active);
        verify(findChild(panel, "feedbackText").text.length > 0, "save feedback reaches the fixed panel slot");
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
    function test_sleepNeverAndLidProfileKeepDurationMeaning() {
        const panel = make("power");
        browse(panel, "suspendDelay-battery");
        keyClick(Qt.Key_V, Qt.AltModifier);
        const suspend = findChild(panel, "suspendDelay-battery");
        const dialog = suspend.exactDialog;
        tryVerify(() => dialog.visible);
        verify(panel.controller.navigationBlocked, "shared exact modal blocks panel commands");
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        keyClick(Qt.Key_R, Qt.AltModifier);
        keyClick(Qt.Key_C, Qt.AltModifier);
        keyClick(Qt.Key_F5);
        compare(panel.controller.viewTab, "power");
        compare(calls.length, 0);
        const exact = findChild(dialog, "promptInput");
        exact.focusInput(true); keyClick("0"); keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].params.battery.sleep_minutes, 0);
        verify(!panel.controller.navigationBlocked, "the preceding host guard is restored on close");
        compare(calls[0].params.battery.hibernate_minutes, 30, "Never does not destroy lid-profile delay");
        panel.controller.suspendPolicyFinished();
        const hibernate = findChild(panel, "hibernateDelay-battery");
        verify(!hibernate.interactive, "no idle sleep and no profile lid action");
        const policy = JSON.parse(JSON.stringify(panel.controller.suspendPolicyDraft));
        policy.lid_action = "profile";
        panel.controller.applySuspendPolicy({available: true, hibernate_available: true, lid: {available: true}, policy: policy});
        verify(hibernate.interactive); compare(hibernate.label, "Then hibernate"); compare(hibernate.value, 30);
        browse(panel, "hibernateDelay-battery");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        compare(calls.length, 2);
        compare(calls[1].params.battery.sleep_minutes, 0);
        compare(calls[1].params.battery.hibernate_minutes, 45);
        panel.controller.suspendPolicyFinished();
        browse(panel, "criticalBatteryEnabled");
        keyClick(Qt.Key_Return);
        tryVerify(() => findChild(panel, "batterySafetyReview").visible);
        verify(panel.controller.navigationBlocked, "the domain review binding survives the exact modal");
        keyClick(Qt.Key_Escape);
        verify(!panel.controller.navigationBlocked);
    }
    function test_unavailableHibernateOnlyAllowsNeverAndSeparateProfiles() {
        const panel = make("power");
        const policy = JSON.parse(JSON.stringify(panel.controller.suspendPolicyDraft));
        policy.same_profile = false;
        policy.plugged = {sleep_minutes: 60, hibernate_minutes: 120};
        panel.controller.applySuspendPolicy({available: true, hibernate_available: false, lid: {available: true}, policy: policy});
        const hibernate = browse(panel, "hibernateDelay-plugged");
        compare(hibernate.value, 180);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        compare(calls.length, 0, "unsupported hibernation cannot be enabled or changed to a finite value");
        keyClick(Qt.Key_V, Qt.AltModifier);
        tryVerify(() => hibernate.exactDialog.visible);
        const exact = findChild(hibernate.exactDialog, "promptInput");
        exact.focusInput(true); keyClick("0"); keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].params.plugged.hibernate_minutes, 0);
        compare(calls[0].params.battery.hibernate_minutes, 30, "only the selected source changes");
    }
    function test_calibrationReviewBlocksCommandsAndRetargeting() {
        const panel = make("care");
        const modal = findChild(panel, "batterySafetyReview");
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => modal.visible);
        verify(modal.compactPresentation && !modal.actionSummaryVisible);
        verify(!findChild(modal, "modalDetail").visible);
        verify(modal.Accessible.description.includes("power supply connected"));
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
        tryVerify(() => calls.some(c => c.method === "battery.operation.start" && c.params.method === "battery.startCalibration"));
        const write = calls.find(c => c.method === "battery.operation.start");
        compare(write.params.params.battery_id, "BAT1");
    }
}
