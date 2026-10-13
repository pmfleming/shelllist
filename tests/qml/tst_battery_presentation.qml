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
    function reveal(panel, item) {
        const page = findChild(panel, "batteryDetailPage");
        page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, item.mapToItem(page.contentItem, 0, 0).y - Ui.Theme.spacingMd));
        verify(waitForRendering(panel));
    }
    function test_sleepTaskCards_data() {
        return [
            {tag: "normal-dark", width: 453, scheme: Qt.Dark},
            {tag: "normal-light", width: 453, scheme: Qt.Light},
            {tag: "narrow-dark", width: 340, scheme: Qt.Dark},
            {tag: "narrow-light", width: 340, scheme: Qt.Light}
        ];
    }
    function test_sleepTaskCards(data) {
        tests.width = data.width;
        Ui.Theme.previewColorScheme = data.scheme;
        const panel = make("power");
        const commands = findChild(panel, "powerSuspendCard");
        const automatic = findChild(panel, "automaticSuspendCard");
        const critical = findChild(panel, "criticalProtectionCard");
        verify(commands && automatic && critical);
        compare(commands.parent, automatic.parent);
        compare(automatic.parent, critical.parent, "three sibling cards, not nested tonal surfaces");
        verify(commands.y + commands.height <= automatic.y);
        verify(automatic.y + automatic.height <= critical.y);
        compare(findChild(automatic, "criticalBatteryEnabled"), null);
        verify(findChild(critical, "criticalBatteryEnabled") !== null);
        compare(findChild(panel, "suspendSameProfile").title, "Same settings on battery & AC");
        compare(findChild(panel, "suspendProfileHeading-battery").text, "Battery & plugged in");
        verify(!findChild(panel, "criticalBatteryPercent").visible);
        verify(!findChild(panel, "suspendProfileCurrent-battery").visible, "unknown source is not reported as current");
        const closedHeight = critical.height;
        const policy = JSON.parse(JSON.stringify(panel.controller.suspendPolicyDraft));
        policy.same_profile = false;
        policy.critical_battery.enabled = true;
        panel.controller.applySuspendPolicy({available: true, active_profile: "plugged", hibernate_available: true, lid: {available: true}, policy: policy});
        verify(waitForRendering(panel));
        compare(findChild(panel, "suspendProfileHeading-battery").text, "On battery");
        compare(findChild(panel, "suspendProfileHeading-plugged").text, "Plugged in");
        verify(!findChild(panel, "suspendProfileCurrent-battery").visible);
        verify(findChild(panel, "suspendProfileCurrent-plugged").visible);
        verify(findChild(panel, "suspendDelay-plugged").visible);
        verify(critical.height > closedHeight);
        const link = findChild(panel, "suspendSameProfile");
        link.title = "Use the same automatic sleep and hibernation settings on battery and when connected to an external power supply";
        verify(waitForRendering(panel));
        verify(link.height >= link.implicitHeight);
        verify(link.focusSurface.width >= 52, "long labels must not shrink the switch");
        verify(link.focusSurface.mapToItem(panel, 0, 0).x + link.focusSurface.width <= panel.width, "switch stays inside the narrow panel");
        compare(findChild(panel, "suspendDelay-battery").Accessible.name, "On battery: suspend after inactivity");
        compare(findChild(panel, "hibernateDelay-plugged").Accessible.name, "Plugged in: time suspended before hibernating");
        compare(findChild(panel, "criticalBatteryGrace").Accessible.name, "Critical-battery warning period");
        for (const name of ["suspendDelay-battery", "hibernateDelay-plugged", "criticalBatteryGrace"]) {
            const field = findChild(panel, name);
            const card = name.startsWith("critical") ? critical : automatic;
            const point = field.mapToItem(card, 0, 0);
            verify(field.width > 0 && point.x >= 0 && point.x + field.width <= card.width + 1, name + " stays inside its card");
            verify(field.mapToItem(panel, 0, 0).x + field.width <= panel.width, name + " is not clipped by the narrow viewport");
        }
        compare(calls.length, 0, "layout, headings and incoming state never write settings");
    }
    function test_sleepFieldTransactionsAndLinkedTraversal() {
        const panel = make("power");
        const sleep = browse(panel, "suspendDelay-battery");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(sleep.value, "30");
        compare(sleep.editSession.displayedValue, "30");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Tab);
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setPolicy");
        compare(calls[0].params.battery.sleep_minutes, 45);
        compare(calls[0].params.same_profile, true, "daemon retains responsibility for applying the linked profile");
        verify(!sleep.interactive, "submitted policy keeps its pending guard");
        panel.controller.suspendPolicyFinished();
        calls = [];
        browse(panel, "suspendSameProfile");
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].params.same_profile, false);
        panel.controller.suspendPolicyFinished();
        verify(waitForRendering(panel));
        browse(panel, "hibernateDelay-battery");
        keyClick(Qt.Key_Tab);
        compare(panel.surface.detailsNavigation.currentTarget, findChild(panel, "suspendDelay-plugged"), "source headings are passive");
        keyClick(Qt.Key_Tab);
        compare(panel.surface.detailsNavigation.currentTarget, findChild(panel, "hibernateDelay-plugged"));
        keyClick(Qt.Key_Tab);
        compare(panel.surface.detailsNavigation.currentTarget, findChild(panel, "criticalBatteryEnabled"), "Help and recovery commands are not field stops");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.surface.detailsNavigation.currentTarget, findChild(panel, "hibernateDelay-plugged"));
        compare(calls.length, 1, "traversal does not save or relink profiles");
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
    function test_powerModeDraftAndAcknowledgement() {
        const panel = make();
        const mode = findChild(panel, "batteryPowerModeProfile");
        compare(panel.surface.detailsNavigation.currentTarget, mode);
        compare(findChild(mode, "segment-balanced").Accessible.name, "Balanced");
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
    function test_hardwareTuningWritesOnlyOnActivation() {
        tests.width = 340;
        const panel = make("power");
        panel.controller.applyPowerProfile(Object.assign({}, panel.controller.powerProfile, {
            battery_aware: true,
            actions: [{name: "amdgpu_dpm", description: "Adjust GPU dynamic power management", enabled: false}]
        }));
        verify(waitForRendering(panel));
        const action = browse(panel, "batteryHardwareAction-amdgpu_dpm");
        compare(calls.length, 0, "layout/icons do not submit settings");
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].method, "powerProfile.setActionEnabled");
        compare(calls[0].params.action, "amdgpu_dpm");
        compare(calls[0].params.enabled, true);
        verify(!action.checked, "toggle waits for daemon acknowledgement");
        verify(!action.interactive);
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
    function test_reopenRestoresFocusWithoutResettingNewNavigation() {
        const panel = make();
        const nav = panel.surface.detailsNavigation;
        keyClick(Qt.Key_Tab);
        compare(nav.currentTarget, findChild(panel, "batteryHistoryRange"));
        panel.controller.prepareUiDeactivation();
        panel.visible = false;
        tests.forceActiveFocus();
        panel.controller.deactivateUiState();
        panel.controller.activateUiState("");
        panel.visible = true;
        tryVerify(() => nav.browsing);
        tryCompare(nav, "currentTarget", findChild(panel, "batteryHistoryRange"));
        keyClick(Qt.Key_Tab);
        const target = nav.currentTarget;
        panel.controller.restoreUiFocus();
        wait(0);
        compare(nav.currentTarget, target, "late host requests do not reset navigation");
        compare(calls.length, 0);
    }
    function test_closureCancelsPendingOpeningFocus() {
        const panel = createTemporaryObject(factory, tests, {visible: false, initiallyActive: true});
        panel.controller.deactivateUiState();
        tests.forceActiveFocus();
        panel.visible = true;
        wait(0);
        verify(!panel.surface.pendingFocus);
        verify(!panel.surface.detailsNavigation.activeFocus);
    }
    function test_historyRangeRemainsTheOnlyChartField() {
        const panel = make();
        const card = findChild(panel, "batteryHistoryCard");
        const graph = findChild(card, "batteryTimelineGraph");
        const range = browse(panel, "batteryHistoryRange");
        verify(!graph.activeFocusOnTab);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(range.displayedValue, "24");
        compare(card.range, "6", "range choice remains a local field draft");
        keyClick(Qt.Key_Escape);
        compare(range.displayedValue, "6");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Tab);
        compare(card.range, "24");
        compare(panel.surface.detailsNavigation.currentTarget, findChild(panel, "batteryEnergyPeriod"), "Tab continues to energy period, skipping tracks and labels");
        compare(calls.length, 0, "history presentation never dispatches a battery mutation");
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
    function test_criticalReviewAndUnavailableDiagnostic() {
        const panel = make("power");
        const critical = browse(panel, "criticalBatteryEnabled");
        keyClick(Qt.Key_Return);
        const modal = findChild(panel, "batterySafetyReview");
        tryVerify(() => modal.visible);
        verify(modal.Accessible.description.includes("one automatic power manager"));
        verify(!findChild(modal, "modalDetail").visible);
        verify(waitForPolish(panel.Window.window));
        const title = findChild(modal, "detailTitle");
        compare(title.elide, Text.ElideNone);
        verify(title.contentHeight <= title.height + 1, "the complete safety question wraps at battery-panel width");
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
        reveal(panel, details);
        mouseClick(details, details.width / 2, details.height / 2);
        verify(findChild(panel, "suspendPolicyDiagnostic").visible);
        verify(findChild(panel, "suspendPolicyDiagnostic").text.includes("nested or inline"));
    }
}
