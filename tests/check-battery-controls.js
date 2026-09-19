#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const [controllerPath, backendPath, flowPath, presentationPath] = process.argv.slice(2);
if (!presentationPath)
    throw new Error("usage: check-battery-controls.js <controller> <backend> <flow> <presentation>");
const source = fs.readFileSync(controllerPath, "utf8");
function library(path) {
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(path, "utf8").replace(/^\.(pragma|import).*$/gm, ""), context);
    return context;
}
function functions(source) {
    return source.match(/^    function [\s\S]*?^    }/gm).join("\n")
        .replace(/function\s+\w+\([^)]*\)\s*(?::\s*\w+)?\s*\{/g,
            header => header.replace(/:\s*(string|bool|var|int|real|void)\b/g, ""));
}
function timer() {
    return { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
}
function controller() {
    const calls = [];
    const context = vm.createContext({
        Flow: library(flowPath), Presentation: library(presentationPath),
        uiActive: false, actionInFlight: false, sendSucceeds: true, backendReady: true,
        thresholdAutoSave: timer(), alertAutoSave: timer(),
        batteryBackend: new Proxy({}, { get: (_, method) => method === "ready" ? context.backendReady : (...args) => {
            calls.push({ method, args });
            return context.sendSucceeds;
        } })
    });
    // Execute the actual controller methods and property expressions, with only
    // its transport and Qt timers replaced. No hardware or D-Bus calls are made.
    for (const match of source.matchAll(/^    (readonly )?property \w+ (\w+): ([\s\S]*?)(?=\n    (?:readonly property|property|function)|\n\n)/gm)) {
        const [, readonly, name, expression] = match;
        if (readonly)
            Object.defineProperty(context, name, { get: () => vm.runInContext(`(${expression})`, context) });
        else
            context[name] = vm.runInContext(`(${expression})`, context);
    }
    vm.runInContext(functions(source), context);
    return { c: context, calls };
}
function device(id, start = 75, end = 80) {
    return { id, protection: { supported: true, desired_enabled: true,
        desired_start_percent: start, desired_end_percent: end,
        available_behaviours: ["inhibit-charge", "force-discharge"] } };
}
function state(devices, extra = {}) {
    return { available: true, plugged: true, devices, ...extra };
}

{
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0"), device("BAT1", 60, 85)]));
    c.selectDevice("BAT1");
    c.updateStartPercent(65, false);
    c.selectDevice("BAT1");
    c.applyBattery(state([device("BAT1", 60, 85), device("BAT0")]));
    c.flushThresholdPolicy();
    assert.deepEqual(calls[0], { method: "setThresholds", args: ["BAT1", 65, 85] },
        "reordered telemetry must preserve both the edited value and target identity");
    c.settingsOperationFinished("threshold");
    c.updateStartPercent(66, false);
    c.applyBattery(state([device("BAT0")]));
    assert.equal(c.flushThresholdPolicy(), false, "removed-device edits must not leak to a replacement");
}

{
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0")]));
    c.setProtection(false);
    c.setProtection(true); // A newer toggle is queued behind the first write.
    c.applyBattery(state([device("BAT1", 60, 85)]));
    c.updateStartPercent(65, false);
    c.settingsOperationFinished("threshold");
    assert.equal(c.thresholdDraftDirty, true, "an old battery's completion must not acknowledge new edits");
    assert.equal(c.flushThresholdPolicy(), true);
    assert.deepEqual(calls[1], { method: "setThresholds", args: ["BAT1", 65, 85] },
        "an abandoned protection toggle must not take ownership of the replacement battery");
}

for (const domain of ["threshold", "alert"]) {
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0")]));
    const update = domain === "threshold" ? c.updateStartPercent : c.updateWarningPercent;
    const flush = domain === "threshold" ? c.flushThresholdPolicy : c.flushAlertPolicy;
    const finish = domain === "threshold" ? c.finishThresholdEditing : c.finishAlertEditing;
    const autoSave = c[domain + "AutoSave"];
    update(30, false);
    assert.equal(flush(), true);
    autoSave.stop(); // Model the timer which dispatched the first request.
    update(31, true);
    c.settingsOperationFinished(domain);
    c.resumePendingSettings();
    assert.equal(flush(), false);
    assert.equal(calls.length, 1);
    finish();
    assert.equal(flush(), true);
    update(32, true);
    autoSave.stop();
    c.settingsOperationFailed(domain, "test failure");
    assert.equal(flush(), false, "failure must not write settings during active editing");
    finish();
    assert.equal(flush(), true);
    c.settingsOperationFinished(domain);
    assert.equal(c[domain + "DraftDirty"], false);
}

for (const extra of [
    { protection: { charge_once_active: true } },
    { operation: { kind: "calibration", battery_id: "BAT1" } },
    { operation: { kind: "inhibit", battery_id: "BAT1" } }
]) {
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0"), device("BAT1")], extra));
    c.updateStartPercent(65, false);
    assert.equal(c.flushThresholdPolicy(), false);
    assert.equal(c.setProtection(false), false);
    assert.equal(c.chargeOnce(), false);
    assert.equal(c.setChargingInhibited(true), false);
    assert.equal(c.toggleCalibration(), false);
    assert.equal(calls.length, 0);
    c.thresholdAutoSave.stop();
    c.applyBattery(state([device("BAT0")]));
    // Simulate Qt's binding notification using the actual signal handler.
    const handler = source.match(/onBatteryOperationActiveChanged: \{([\s\S]*?)^    }/m)[1];
    vm.runInContext(handler, c);
    assert.equal(c.thresholdAutoSave.running, true, "temporary-operation completion must resume pending settings");
    assert.equal(c.flushThresholdPolicy(), true);
}
{
    const { c } = controller();
    const other = device("BAT1");
    other.protection.charge_once_active = true;
    c.applyBattery(state([device("BAT0"), other]));
    assert.equal(c.batteryOperationActive, true, "charge-once on a secondary battery is global");
}
{
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0")], { plugged: false }));
    assert.equal(c.toggleCalibration(), false, "starting calibration requires AC");
    c.applyBattery(state([device("BAT0")], { plugged: false,
        operation: { kind: "calibration", battery_id: "BAT0" } }));
    assert.equal(c.toggleCalibration(), true, "cancellation must remain available after unplugging");
    assert.equal(calls[0].method, "cancelCalibration");
}
{
    const { c, calls } = controller();
    c.powerSleep = { available: true, can_suspend: "yes", can_hibernate: "challenge" };
    // The backend dispatch test below owns the action allowlist.
    for (const capability of ["no", "na", "", undefined]) {
        c.powerSleep.can_suspend = capability;
        assert.equal(c.powerSleepAction("suspend"), false);
    }
    c.powerSleep.can_suspend = "yes";
    c.powerSleep.preparing_for_sleep = true;
    assert.equal(c.powerSleepAction("suspend"), false);
    assert.equal(c.powerSleepAction("hibernate"), false);
    assert.equal(c.powerSleepAction("lock"), false);
    c.powerSleep.preparing_for_sleep = false;
    assert.equal(c.powerSleepAction("lock"), true);
    assert.equal(c.sleepStatus, "Locking…");
    assert.equal(c.powerSleepAction("hibernate"), false, "pending lock prevents duplicate requests");
    c.operationFinished("power-sleep-lock-1");
    assert.equal(c.sleepStatus, "");
    assert.equal(c.powerSleepAction("hibernate"), true);
    c.operationFinished("power-sleep-hibernate-2");
    c.powerSleep.available = false;
    assert.equal(c.powerSleepAction("lock"), false);
    assert.equal(calls.length, 2);
}
{
    const { c, calls } = controller();
    c.applyPowerSleep({ available: true, can_suspend: "yes", can_hibernate: "yes" });
    assert.equal(c.setKeepAwake(true), false, "older daemon must not offer unsupported control");
    c.applyPowerSleep({ ...c.powerSleep, keep_awake: false });
    assert.equal(c.setKeepAwake(true), true);
    assert.equal(c.keepAwake, false, "wait for daemon confirmation, not an optimistic toggle");
    assert.equal(c.keepAwakePending, true);
    assert.equal(c.setKeepAwake(true), false, "suppress repeated clicks");
    assert.equal(c.canPowerSleepAction("suspend"), false);
    assert.deepEqual(calls[0], { method: "setKeepAwake", args: [true] });
    c.operationFinished("power-keep-awake-1");
    c.applyPowerSleep({ ...c.powerSleep, keep_awake: true });
    assert.equal(c.keepAwake, true);
    assert.equal(c.canPowerSleepAction("suspend"), false);
    assert.equal(c.canPowerSleepAction("hibernate"), false);
    assert.equal(c.canPowerSleepAction("lock"), true);
    assert.equal(c.setKeepAwake(false), true);
    c.operationFailed("power-keep-awake-2", "denied");
    assert.equal(c.keepAwake, true, "failed release must not claim sleep is allowed");
    assert.equal(c.keepAwakePending, false);
    assert.equal(c.keepAwakeError, "denied");
    assert.equal(c.sleepRetryAction, "", "a failed toggle must never offer a sleep retry");
    c.sendSucceeds = false;
    assert.equal(c.setKeepAwake(false), false);
    assert.equal(c.keepAwakePending, false);
    assert.equal(c.actionInFlight, false);
    c.sendSucceeds = true;
    assert.equal(c.setKeepAwake(false), true);
    c.backendReady = false;
    c.transportFailed("disconnected");
    assert.equal(c.keepAwakePending, false);
    assert.equal(c.canSetKeepAwake, false);
    assert.equal(c.canPowerSleepAction("lock"), false, "stale telemetry is not actionable");
    assert.ok(c.keepAwakeError.includes("unknown"));
    c.backendReady = true;
    c.applyPowerSleep({ ...c.powerSleep, available: true, keep_awake: false });
    assert.equal(c.canSetKeepAwake, true);
    assert.equal(c.keepAwakeError, "", "fresh snapshot resolves connection uncertainty");
}
{
    const { c, calls } = controller();
    assert.equal(c.setPreferExternal(true), false, "integration is opt-in");
    c.applyDisplayPolicy({ available: true, policy: { prefer_external: true }, status: "external" });
    assert.equal(c.setPreferExternal(false), true);
    assert.deepEqual(calls[0], { method: "setDisplayPolicy", args: [false] });
    assert.equal(c.displayPolicyState.policy.prefer_external, true, "no optimistic preference before save");
    assert.equal(c.setPreferExternal(true), false, "saving is serialized");
    c.operationFailed("display-policy-1", "disk full");
    assert.equal(c.displayPolicySaving, false);
    assert.equal(c.displayPolicyError, "disk full");
    assert.equal(c.lastError, "", "display errors stay in their card");
    c.backendReady = false;
    assert.equal(c.setPreferExternal(false), false);
    c.backendReady = true;
    assert.equal(c.setPreferExternal(false), true);
    c.operationFinished("display-policy-2");
    c.applyDisplayPolicy({ available: true, policy: { prefer_external: false }, status: "pending" });
    assert.equal(c.displayPolicyError, "");
    assert.equal(c.displayPolicyState.policy.prefer_external, false);
    c.sendSucceeds = false;
    assert.equal(c.setPreferExternal(true), false);
    assert.equal(c.displayPolicySaving, false);
}
for (const reportedActive of [false, true]) {
    const { c, calls } = controller();
    c.applyPowerSleep({ available: false, keep_awake: reportedActive, preparing_for_sleep: true,
        error: "logind telemetry unavailable" });
    assert.equal(c.canSetKeepAwake, true, "release is independent of telemetry and preparation hints");
    assert.equal(c.setKeepAwake(true), false, "must never acquire protection with unavailable telemetry");
    assert.equal(c.toggleKeepAwake(), true, "click always releases when telemetry is unavailable");
    assert.deepEqual(calls[0], { method: "setKeepAwake", args: [false] });
    assert.equal(c.toggleKeepAwake(), false, "duplicate releases remain guarded");
    c.operationFinished("power-keep-awake-1");
    c.sleepPendingAction = "suspend";
    assert.equal(c.setKeepAwake(false), false);
    c.sleepPendingAction = "";
    c.backendReady = false;
    assert.equal(c.setKeepAwake(false), false, "disconnected transport is not actionable");
    c.backendReady = true;
    assert.equal(c.setKeepAwake(false), true, "reconnection permits release before healthy telemetry returns");
}
{
    const { c, calls } = controller();
    c.powerProfile = { available: false, profiles: [{ name: "balanced" }],
        battery_aware: true, actions: [{ name: "test-action" }] };
    assert.equal(c.setBatteryAware(false), false);
    assert.equal(c.setPowerActionEnabled("test-action", false), false);
    assert.equal(c.setPowerProfile("balanced"), false);
    c.powerProfile.available = true;
    assert.equal(c.setPowerProfile("performance"), false);
    assert.equal(c.setPowerActionEnabled("unknown", false), false);
    assert.equal(calls.length, 0);
    assert.equal(c.setPowerProfile("balanced"), true);
}
{
    const calls = [];
    const backend = vm.createContext({
        BatteryApi: { methods: { lock: "lock", suspend: "suspend", hibernate: "hibernate", setKeepAwake: "powerSleep.setKeepAwake" } },
        callSequenced: (...args) => { calls.push(args); return true; }
    });
    vm.runInContext(functions(fs.readFileSync(backendPath, "utf8")), backend);
    for (const action of ["", "typo", "toString", "__proto__"])
        assert.equal(backend.powerSleepAction(action), false);
    assert.equal(calls.length, 0, "unknown actions must never dispatch hibernate");
    for (const action of ["lock", "suspend", "hibernate"])
        assert.equal(backend.powerSleepAction(action), true);
    assert.deepEqual(calls.map(call => call[1]), ["lock", "suspend", "hibernate"]);
    assert.equal(backend.setKeepAwake(true), true);
    assert.deepEqual(JSON.parse(JSON.stringify(calls[3])),
        ["power-keep-awake", "powerSleep.setKeepAwake", { enabled: true }]);
}
{
    const { c, calls } = controller();
    c.applyBattery(state([], { policy: { warning_percent: 35, critical_percent: 10,
        auto_power_saver: false, notify_when_full: false } }));
    assert.equal(c.draftWarningProfile, "keep-current", "legacy saver off migrates both levels");
    assert.equal(c.draftCriticalProfile, "keep-current");
    assert.equal(c.draftNotifyWarning, true);
    assert.equal(c.draftNotifyCritical, true);
    assert.equal(c.draftNotifyWhenFull, false);
    c.applyPowerProfile({ available: true, profiles: [{ name: "balanced" }, { name: "power-saver" }],
        battery_automation: { level: "low", status: "paused", profile: "power-saver" } });
    c.updateLevelProfile("low", "balanced");
    assert.equal(calls[0].method, "setAlertPolicy");
    assert.deepEqual(JSON.parse(JSON.stringify(calls[0].args[0])), {
        warning_percent: 35, critical_percent: 10, notify_when_full: false,
        notify_warning: true, notify_critical: true, warning_profile: "balanced", critical_profile: "keep-current"
    });
    c.settingsOperationFinished("alert");
    c.updateLevelNotification("low", false);
    assert.equal(calls[1].args[0].warning_profile, "balanced", "notification switch does not disable its profile action");
    c.settingsOperationFinished("alert");
    c.updateLevelProfile("critical", "performance");
    assert.equal(calls.length, 2, "unavailable profiles cannot be selected");
    c.updateLevelProfile("critical", "power-saver");
    c.settingsOperationFinished("alert");
    assert.equal(c.draftWarningProfile, "balanced");
    assert.equal(c.draftCriticalProfile, "power-saver");
    assert.match(c.automationStatus, /paused/);
    assert.equal(c.resumeAutomaticProfiles(), true);
    assert.equal(calls.at(-1).method, "resumeAutomaticProfiles");
    c.actionInFlight = false;
    c.applyPowerProfile({ available: true, battery_automation: { status: "active" } });
    assert.equal(c.resumeAutomaticProfiles(), false);
}
{
    const { c, calls } = controller();
    c.applyPowerProfile({ available: true, profiles: [{ name: "balanced" }, { name: "power-saver" }] });
    c.applyBattery(state([], { policy: { warning_percent: 35, critical_percent: 10,
        warning_profile: "balanced", critical_profile: "power-saver", notify_warning: true, notify_critical: true } }));
    assert.equal(c.levelProfileOptions.length, 3);
    c.updateLevelEnabled("low", false);
    assert.equal(calls[0].args[0].warning_profile, "keep-current");
    assert.equal(calls[0].args[0].notify_warning, false, "disabling a level disables its notification");
    assert.equal(calls[0].args[0].notify_critical, true, "other level notification is unchanged");
    assert.equal(c.draftCriticalProfile, "power-saver", "levels toggle independently");
    assert.equal(c.draftWarningPercent, 35, "disabling preserves the threshold");
    c.settingsOperationFinished("alert");
    c.updateLevelEnabled("low", true);
    assert.equal(c.draftWarningProfile, "balanced", "re-enabling restores the previous profile");
    assert.equal(calls[1].args[0].notify_warning, true, "enabling a level enables its notification in the same save");
    c.settingsOperationFinished("alert");
    c.applyPowerProfile({ available: false, profiles: [] });
    c.updateLevelEnabled("low", false);
    assert.equal(c.draftWarningProfile, "keep-current", "can disable an unavailable profile");
    c.settingsOperationFinished("alert");
    c.updateLevelEnabled("low", true);
    assert.equal(c.draftWarningProfile, "keep-current", "cannot enable unavailable profiles");
    assert.equal(c.draftNotifyWarning, true, "notifications work without a profile service");
    assert.equal(calls.at(-1).args[0].notify_warning, true);
    c.settingsOperationFinished("alert");
    c.applyPowerProfile({ available: true, profiles: [{ name: "power-saver" }] });
    c.updateLevelEnabled("low", true);
    assert.equal(c.draftWarningProfile, "power-saver", "falls back to an available profile");
}
{
    const { c, calls } = controller();
    c.powerSleep = { available: true, can_suspend: "yes", can_hibernate: "na", inhibitors: [] };
    assert.equal(c.powerSleepAction("suspend"), true);
    assert.equal(c.actionInFlight, true);
    assert.equal(c.sleepPendingAction, "suspend");
    assert.equal(c.powerSleepAction("suspend"), false);
    assert.equal(calls.length, 1);
    c.powerSleep.preparing_for_sleep = true;
    assert.equal(c.sleepStatus, "Preparing sleep…");
    c.powerSleep.preparing_for_sleep = false;
    c.operationFailed("power-sleep-suspend-1", "Screen lock was not confirmed");
    assert.equal(c.actionInFlight, false);
    assert.equal(c.sleepPendingAction, "");
    assert.equal(c.sleepStatus, "Suspend failed");
    assert.equal(c.sleepRetryAction, "suspend");
    assert.equal(c.lastError, "", "sleep errors stay local to the sleep controls");
    assert.equal(c.canPowerSleepAction(c.sleepRetryAction), true);
    assert.equal(c.powerSleepAction(c.sleepRetryAction), true);
    assert.equal(c.sleepError, "");
    c.operationFinished("power-sleep-suspend-2");
    assert.equal(c.sleepRetryAction, "");
    assert.equal(c.sleepStatus, "");
    c.sendSucceeds = false;
    assert.equal(c.powerSleepAction("lock"), false);
    assert.equal(c.actionInFlight, false, "synchronous rejection cannot leave the controls busy");
    assert.equal(c.sleepStatus, "Lock failed");
    c.sendSucceeds = true;
    assert.equal(c.powerSleepAction("suspend"), true);
    c.transportFailed("Transport closed");
    assert.equal(c.sleepPendingAction, "");
    assert.equal(c.actionInFlight, false);
    assert.match(c.sleepError, /may already have been accepted/);
    assert.equal(c.sleepRetryAction, "suspend");
}
{
    const { c, calls } = controller();
    const policy = { same_profile: false,
        battery: { sleep_minutes: 15, hibernate_minutes: 60 },
        plugged: { sleep_minutes: 45, hibernate_minutes: 180 } };
    const state = { available: true, policy, active_profile: "battery" };
    c.applySleepPolicy(state);
    assert.equal(c.updateSleepPolicy("", "same_profile", true), true);
    assert.equal(c.sleepPolicySaving, true);
    assert.equal(c.updateSleepPolicy("battery", "sleep_minutes", 30), false, "pending save prevents duplicate writes");
    assert.equal(calls[0].method, "setSleepPolicy");
    assert.equal(calls[0].args[0].same_profile, true);
    assert.equal(calls[0].args[0].plugged.hibernate_minutes, 180, "shared mode retains the separate AC profile");
    c.applySleepPolicy(state);
    assert.equal(c.sleepPolicyDraft.same_profile, true, "stale telemetry must not overwrite an in-flight edit");
    c.sleepPolicyFailed("hypridle restart failed");
    assert.equal(c.sleepPolicyDirty, true);
    assert.equal(c.sleepPolicySaving, false);
    assert.equal(c.sleepPolicyError, "hypridle restart failed");
    assert.equal(c.saveSleepPolicy(), true, "failed saves offer explicit retry");
    c.sleepPolicyFinished();
    c.applySleepPolicy({ ...state, policy: calls[1].args[0] });
    assert.equal(c.sleepPolicyDirty, false);
    assert.equal(c.sleepPolicyDraft.same_profile, true);
    assert.equal(c.updateSleepPolicy("", "same_profile", false), true);
    assert.equal(c.sleepPolicyDraft.plugged.sleep_minutes, 45);
    c.sleepPolicyFinished();
    assert.equal(c.updateSleepPolicy("", "lid_action", "shutdown"), false);
    for (const action of ["system", "ignore", "lock", "suspend", "hibernate", "profile"]) {
        assert.equal(c.updateSleepPolicy("", "lid_action", action), true);
        assert.equal(calls.at(-1).args[0].lid_action, action);
        c.sleepPolicyFinished();
    }
    for (const value of [-1, 1.5, 10081, NaN])
        assert.equal(c.updateSleepPolicy("battery", "sleep_minutes", value), false);
    assert.equal(c.updateSleepPolicy("battery", "sleep_minutes", 0), true, "Never is a valid sleep delay");
    c.transportFailed("disconnected");
    assert.equal(c.sleepPolicySaving, false);
    assert.match(c.sleepPolicyError, /may have been saved/);
    c.sleepPolicyState.available = false;
    assert.equal(c.saveSleepPolicy(), false, "unmanaged integration never claims settings were applied");
}

// Connectivity errors expire only after a successful snapshot; effect errors
// must remain visible because telemetry cannot acknowledge a lost operation.
for (const operation of ["none", "effect", "threshold", "alert"]) {
    const { c } = controller();
    c.actionInFlight = operation === "effect";
    c.thresholdOperationActive = operation === "threshold";
    c.alertOperationActive = operation === "alert";
    c.transportFailed("connection lost");
    assert.equal(c.transportError, "connection lost");
    c.refreshFinished("battery-history-1");
    assert.equal(c.transportError, "connection lost", "history alone does not confirm live status");
    c.refreshFinished("battery-snapshot-2");
    assert.equal(c.transportError, "");
    assert.equal(c.lastError, operation === "effect" ? "connection lost" : "");
    if (operation === "threshold" || operation === "alert")
        assert.equal(c[operation + "SaveError"], "connection lost", "recovery must retain failed saves");
}
{
    const { c } = controller();
    c.operationFailed("battery-charge-once-1", "permission denied");
    c.transportFailed("connection lost");
    c.refreshFinished("battery-snapshot-2");
    assert.equal(c.lastError, "permission denied", "recovery must not erase an earlier operation error");
}

console.log("battery controls: selection, auto-save, level actions, sleep profiles, failure/retry and dispatch passed");
