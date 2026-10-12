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
    Component {
        id: windowFactory
        Window {
            id: host
            width: tests.width
            height: tests.height
            property alias controller: controller
            property alias surface: surface
            Battery.BatteryController { id: controller }
            Battery.BatteryContent { id: surface; controller: host.controller }
        }
    }
    function init() { failOnWarning(/.*/); }
    function cleanup() { Ui.Theme.previewColorScheme = Qt.Unknown; tests.width = 453; }
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
    function luminance(color) {
        function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
    }
    function verifyMutedIcon(color, background) {
        const chroma = Math.max(color.r, color.g, color.b) - Math.min(color.r, color.g, color.b);
        verify(chroma >= 0.10 && chroma < 0.30, "muted but visibly coloured glyphs");
        compare(color.a, 1);
        const a = luminance(color), b = luminance(background);
        verify((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05) >= 3, "small icons retain contrast");
    }
    function test_modeIsFirstCircularAndDeferred_data() {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_modeIsFirstCircularAndDeferred(data) {
        Ui.Theme.previewColorScheme = data.scheme;
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
        const icons = ["eco", "balance", "speed"];
        const colors = [];
        for (let i = 0; i < mode.options.length; ++i) {
            const option = mode.options[i];
            const segment = findChild(mode, "segment-" + option.value);
            const glyph = findChild(segment, "controlIcon");
            compare(glyph.icon, icons[i]);
            compare(glyph.iconColor, segment.selected ? option.selectedIconColor : option.iconColor);
            const color = glyph.iconColor;
            colors.push(String(option.iconColor));
            verifyMutedIcon(color, Ui.Theme.controlBackground);
            verifyMutedIcon(color, Ui.Theme.selected);
        }
        compare(new Set(colors).size, 3, "each profile has a distinct tint");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(mode.displayedValue, "performance");
        compare(findChild(findChild(mode, "segment-performance"), "controlIcon").iconColor,
                mode.options[2].selectedIconColor);
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
    function test_sleepButtonColours_data() {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_sleepButtonColours(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const panel = make("power");
        panel.controller.applyPowerSuspend({available: true, can_suspend: "yes", can_hibernate: "yes", keep_awake: false, inhibitors: []});
        const colours = [];
        for (const name of ["keepAwakeButton", "suspendAction-lock", "suspendAction-suspend", "suspendAction-hibernate"]) {
            const button = findChild(panel, name);
            verify(button.enabled);
            compare(findChild(button, "controlIcon").iconColor, button.iconColor);
            verifyMutedIcon(button.iconColor, button.backgroundColor);
            verifyMutedIcon(button.iconColor, button.hoverBackgroundColor);
            colours.push(String(button.iconColor));
        }
        compare(new Set(colours).size, 4);
        panel.controller.applyPowerSuspend({available: true, can_suspend: "yes", can_hibernate: "yes", keep_awake: true, inhibitors: []});
        const awake = findChild(panel, "keepAwakeButton");
        compare(awake.iconColor, awake.labelColor, "active Keep awake keeps its contrasting foreground");
        compare(awake.backgroundColor, Ui.Theme.accent);
        verify(!findChild(panel, "suspendAction-suspend").enabled);
        verify(!findChild(panel, "suspendAction-hibernate").enabled);
        compare(calls.length, 0, "palette updates do not dispatch actions");
    }
    function test_hardwareTuningLabelsAndIcons_data() {
        return [{tag: "normal", panelWidth: 453}, {tag: "narrow", panelWidth: 340}];
    }
    function test_hardwareTuningLabelsAndIcons(data) {
        tests.width = data.panelWidth;
        const panel = make("power");
        panel.controller.applyPowerProfile(Object.assign({}, panel.controller.powerProfile, {
            battery_aware: true,
            actions: [
                {name: "trickle_charge", enabled: true},
                {name: "amdgpu_panel_power", description: "Panel power savings (may affect colour quality)", enabled: false},
                {name: "amdgpu_dpm", description: "Adjust GPU dynamic power management", enabled: false},
                {name: "future_action", description: "An additional hardware action", enabled: false}
            ]
        }));
        const names = ["batteryAdaptiveTuning", "batteryHardwareAction-trickle_charge", "batteryHardwareAction-amdgpu_panel_power", "batteryHardwareAction-amdgpu_dpm", "batteryHardwareAction-future_action"];
        const icons = ["tune", "battery_charging_full", "monitor", "memory", "tune"];
        verify(waitForRendering(panel));
        for (let i = 0; i < names.length; i++) {
            const row = findChild(panel, names[i]);
            compare(findChild(row, "fieldRowIcon").symbol, icons[i]);
            const label = findChild(row, "fieldRowLabel");
            const right = label.mapToItem(row, label.width, 0).x;
            compare(Math.round(right + Ui.Theme.spacingMd), Math.round(row.focusSurface.mapToItem(row, 0, 0).x));
            verify(row.Accessible.name.includes(row.title));
        }
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
    function test_windowOpeningFocus() {
        const host = createTemporaryObject(windowFactory, tests);
        host.controller.applyPowerProfile({available: true, profile: "balanced", profiles: [{name: "power-saver"}, {name: "balanced"}, {name: "performance"}]});
        host.controller.activateUiState("");
        wait(0);
        host.show();
        host.requestActivate();
        tryVerify(() => host.active);
        tryVerify(() => host.surface.detailsNavigation.browsing);
        compare(host.surface.detailsNavigation.currentTarget, findChild(host, "batteryPowerModeProfile"));
        host.close();
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
    function test_historyFeedbackUsesStatusBar() {
        const panel = make();
        const card = findChild(panel, "batteryHistoryCard");
        const source = findChild(card, "batteryHistoryInspection");
        const status = findChild(panel, "panelFeedback");
        const label = findChild(status, "feedbackText");
        verify(source instanceof Ui.FeedbackSource);
        compare(source.height, 0, "history feedback reserves no card space");
        tryVerify(() => label.text.includes("Observed time"));
        const statusHeight = status.height;
        const cardHeight = card.height;
        const graph = findChild(card, "batteryTimelineGraph");
        const charge = findChild(card, "batteryHistoryPlot");
        card.history = {points: [
            {timestamp_ms: 86400000, active_time_ms: 0, percentage: 80, power_watts: 8, charging: true, power_valid: true},
            {timestamp_ms: 90000000, active_time_ms: 3600000, percentage: 87, power_watts: 8.4, charging: true, power_valid: true, continuous: true}
        ]};
        browse(panel, "batteryHistoryRange");
        verify(waitForRendering(panel));
        mouseClick(charge, charge.width * 0.3, charge.height / 2);
        verify(graph.inspecting);
        tryVerify(() => label.text.includes("80%") && label.text.includes("8.0 W in"));
        verify(label.parent.fullText.includes(graph.inspectionText), "full timestamp remains accessible");
        compare(card.height, cardHeight);
        compare(status.height, statusHeight);
        keyClick(Qt.Key_Escape);
        mouseMove(panel, 1, 1);
        tryVerify(() => label.text.includes("Observed time"));
        panel.controller.lastError = "Battery operation failed";
        tryCompare(label.parent, "primarySummary", "Battery operation needs attention");
        compare(status.height, statusHeight);
        panel.controller.lastError = "";
        panel.controller.selectViewTab("care");
        tryVerify(() => !label.parent.fullText.includes("Observed time"), 5000, "hidden history contributes no status");
        compare(calls.length, 0);
    }
    function test_combinedChargingTargetsAndDeferredThresholds_data() {
        return [{tag: "dark", scheme: Qt.Dark}];
    }
    function test_combinedChargingTargetsAndDeferredThresholds(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const panel = make("care");
        const notify = findChild(panel, "batteryChargeNotificationToggle");
        const card = findChild(panel, "batteryProtectionCard");
        verify(notify.mapToItem(card, 0, 0).y >= 0);
        const actionRow = findChild(panel, "batteryChargingActionRow");
        const gap = actionRow.mapToItem(card, 0, 0).y - notify.mapToItem(card, 0, notify.height).y;
        verify(gap >= card.contentSpacing + Ui.Theme.spacingSm - 1, "extra breathing room above the entire command row");
        const colors = [];
        for (const action of ["once", "pause", "calibrate"]) {
            const button = findChild(panel, "batteryCareAction-" + action);
            const color = findChild(button, "controlIcon").iconColor;
            compare(color, button.iconColor);
            compare(color.a, 1);
            verify(Math.max(color.r, color.g, color.b) - Math.min(color.r, color.g, color.b) < 0.15);
            colors.push(String(color));
        }
        compare(new Set(colors).size, 3);
        verify(findChild(panel, "batteryChargeNotificationCard") === null);
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
        tryVerify(() => calls.some(c => c.method === "battery.setThresholds"));
        const write = calls.find(c => c.method === "battery.setThresholds");
        compare(write.params.battery_id, "BAT0");
        verify(write.params.start_percent < 85);
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
        const page = findChild(panel, "batteryDetailPage");
        page.contentY = page.contentHeight - page.height;
        verify(waitForRendering(panel));
        mouseClick(details, details.width / 2, details.height / 2);
        verify(findChild(panel, "suspendPolicyDiagnostic").visible);
        verify(findChild(panel, "suspendPolicyDiagnostic").text.includes("nested or inline"));
    }
}
