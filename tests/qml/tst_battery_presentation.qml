pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Battery as Battery
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import "../../bar/BarProtocol.generated.js" as Api

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
    function settingCalls(method) {
        return calls.filter(call => call.method === method || (call.method === "battery.operation.start" && call.params.method === method));
    }
    function respondSetting(call, data, error = "") {
        let envelope = {protocol: Api.protocol, version: Api.version, ok: !error, data: data};
        if (error) envelope.error = {code: "settings-failed", message: error};
        else if (call.method === "battery.operation.start") envelope = {protocol: Api.protocol, version: Api.version, ok: true,
            data: {operation: {id: "settings-test", state: "finished", response: envelope}}};
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, envelope, "", call.route);
    }
    function test_historyRangeIsADeferredReadNotAPerKeyRequest() {
        const panel = make();
        browse(panel, "batteryHistoryRange");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right);
        compare(panel.controller.historyHours, 6);
        compare(settingCalls("battery.history").length, 0);
        keyClick(Qt.Key_Escape);
        compare(panel.controller.historyHours, 6);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        compare(panel.controller.historyHours, 24);
        compare(settingCalls("battery.history").length, 1);
        compare(settingCalls("battery.history")[0].params, {hours: 24});
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Tab);
        compare(panel.controller.historyHours, 168);
        compare(settingCalls("battery.history").length, 2);
        compare(settingCalls("battery.history")[1].params, {hours: 168});
    }
    function test_thresholdAndAlertAcknowledgementsStayIndependent() {
        const panel = make("care");
        const settings = panel.controller.settings;
        const resume = browse(panel, "batteryResumeCharging");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right);
        wait(550);
        compare(settingCalls("battery.setThresholds").length, 0, "native editing cannot enter the debounce queue");
        compare(settings.draftStartPercent, 85);
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        tryVerify(() => settingCalls("battery.setThresholds").length === 1);
        const first = settingCalls("battery.setThresholds")[0];
        compare(first.params.params, {battery_id: "BAT0", start_percent: 86, end_percent: 90});
        respondSetting(first, {}, "Threshold outcome unknown");
        compare(settings.thresholdSaveError, "Threshold outcome unknown");
        verify(settings.thresholdDraftDirty && !settings.thresholdOperationActive);
        wait(650);
        compare(settingCalls("battery.setThresholds").length, 1);
        browse(panel, "batteryChargeNotificationToggle");
        keyClick(Qt.Key_Return);
        tryVerify(() => settingCalls("battery.setAlertPolicy").length === 1);
        const acknowledged = battery();
        acknowledged.policy = Object.assign({}, settings.alertDraft);
        respondSetting(settingCalls("battery.setAlertPolicy")[0], {battery: acknowledged});
        verify(!settings.alertDraftDirty && !settings.alertOperationActive);
        compare(settings.thresholdSaveError, "Threshold outcome unknown");
        compare(panel.controller.lastError, "Threshold outcome unknown");
        compare(settings.draftStartPercent, 86, "an unrelated snapshot cannot replace the failed saved draft");
        browse(panel, "batteryResumeCharging");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        tryVerify(() => settingCalls("battery.setThresholds").length === 2);
        const retry = settingCalls("battery.setThresholds")[1];
        compare(retry.params.params.start_percent, 87);
        const observed = battery();
        observed.devices[0].protection.desired_start_percent = 87;
        respondSetting(retry, {battery: observed});
        verify(!settings.thresholdDraftDirty && !settings.thresholdOperationActive);
        compare(settings.thresholdSaveError, "");
        compare(resume.value, 87);
    }
    function test_deviceReplacementCancelsOnlyItsUnsubmittedThresholdDraft() {
        const panel = make("care");
        browse(panel, "batteryResumeCharging");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right); keyClick(Qt.Key_Return);
        verify(panel.controller.settings.thresholdDraftDirty);
        panel.controller.applyBattery(battery("BAT1"));
        compare(panel.controller.selectedDevice.id, "BAT1");
        compare(panel.controller.settings.draftStartPercent, 85);
        verify(!panel.controller.settings.thresholdDraftDirty);
        wait(650);
        compare(settingCalls("battery.setThresholds").length, 0, "a replacement battery never inherits queued settings");
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
    function test_lidFieldUsesSharedSaveAndDiscard() {
        const panel = make("power");
        const lid = browse(panel, "lidCloseAction");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Home);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(lid.value, "suspend");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Home); keyClick(Qt.Key_Tab);
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setPolicy");
        compare(calls[0].params.lid_action, "system");
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
