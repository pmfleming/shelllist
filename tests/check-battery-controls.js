#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const [controllerPath, flowPath, presentationPath] = process.argv.slice(2);
if (!presentationPath)
    throw new Error("usage: check-battery-controls.js <controller> <flow> <presentation>");
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
    c.flushThresholdPolicy();
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
    flush();
    autoSave.stop(); // Model the timer which dispatched the first request.
    update(31, true);
    c.settingsOperationFinished(domain);
    c.resumePendingSettings();
    flush();
    assert.equal(calls.length, 1, "active editing must not dispatch the queued draft");
    finish();
    flush();
    update(32, true);
    autoSave.stop();
    c.settingsOperationFailed(domain, "test failure");
    assert.equal(flush(), false, "failure must not write settings during active editing");
    finish();
    flush();
    c.settingsOperationFinished(domain);
    assert.equal(domain === "threshold" ? calls.at(-1).args[1] : calls.at(-1).args[0].warning_percent,
        32, "finishing the edit retries the latest queued value, not an older draft");
}

for (const extra of [
    { protection: { charge_once_active: true } },
    { operation: { kind: "calibration", battery_id: "BAT1" } },
    { operation: { kind: "inhibit", battery_id: "BAT1" } }
]) {
    const { c, calls } = controller();
    c.applyBattery(state([device("BAT0"), device("BAT1")], extra));
    c.updateStartPercent(65, false);
    c.flushThresholdPolicy();
    c.setProtection(false);
    c.chargeOnce();
    c.setChargingInhibited(true);
    c.toggleCalibration();
    assert.equal(calls.length, 0);
    c.thresholdAutoSave.stop();
    c.applyBattery(state([device("BAT0")]));
    // Simulate Qt's binding notification using the actual signal handler.
    const handler = source.match(/onBatteryOperationActiveChanged: \{([\s\S]*?)^    }/m)[1];
    vm.runInContext(handler, c);
    assert.equal(c.thresholdAutoSave.running, true, "temporary-operation completion must resume pending settings");
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
    c.toggleCalibration(); // The sole request below must be cancellation, not start.
    c.applyBattery(state([device("BAT0")], { plugged: false,
        operation: { kind: "calibration", battery_id: "BAT0" } }));
    c.toggleCalibration();
    assert.equal(calls[0].method, "cancelCalibration");
}

// Qt's BatterySuspend/BatteryTabs suites own visible status, busy controls,
// independent level toggles and acknowledged Keep awake state. Keep the extra
// command guards and transport failure paths here, not a second UI-state matrix.
{
    const { c, calls } = controller();
    c.powerSuspend = { available: true, can_suspend: "yes", can_hibernate: "challenge" };
    for (const capability of ["no", "na", "challenge", "inhibited", "inhibitor-blocked", "challenge-inhibitor-blocked", "", undefined]) {
        c.powerSuspend.can_suspend = capability;
        c.powerSuspendAction("suspend");
    }
    c.powerSuspend.can_suspend = "yes";
    for (const action of ["", "typo", "toString", "__proto__"])
        c.powerSuspendAction(action);
    c.powerSuspend.preparing_for_sleep = true;
    c.powerSuspendAction("lock");
    c.powerSuspend.preparing_for_sleep = false;
    c.powerSuspendAction("lock");
    c.powerSuspendAction("hibernate");
    c.operationFinished("power-suspend-lock-1");
    c.powerSuspendAction("hibernate");
    c.powerSuspend.can_hibernate = "yes";
    c.powerSuspendAction("hibernate");
    c.operationFinished("power-suspend-hibernate-2");
    c.powerSuspend.available = false;
    c.powerSuspendAction("lock");
    c.backendReady = false;
    c.transportFailed("disconnected");
    c.powerSuspendAction("lock");
    assert.equal(calls.length, 2, "denied, pending, unavailable and disconnected commands must never dispatch");
}
{
    const { c } = controller();
    c.applyPowerSuspend({ available: true, can_suspend: "yes", keep_awake: true });
    c.setKeepAwake(false);
    c.operationFailed("power-keep-awake-1", "denied");
    c.sendSucceeds = false;
    c.setKeepAwake(false);
    assert.equal(c.actionInFlight, false, "synchronous failure cannot strand controls busy");
    c.sendSucceeds = true;
    c.setKeepAwake(false);
    c.backendReady = false;
    c.transportFailed("disconnected");
    assert.ok(c.keepAwakeError.includes("unknown"));
    c.backendReady = true;
    c.applyPowerSuspend({ available: true, keep_awake: false });
    assert.equal(c.keepAwakeError, "", "fresh snapshot resolves connection uncertainty");
}
for (const reportedActive of [false, true]) {
    const { c, calls } = controller();
    c.applyPowerSuspend({ available: false, keep_awake: reportedActive, preparing_for_sleep: true });
    c.setKeepAwake(true);
    c.suspendPendingAction = "suspend";
    c.setKeepAwake(false);
    c.suspendPendingAction = "";
    c.backendReady = false;
    c.setKeepAwake(false);
    assert.equal(calls.length, 0, "unavailable acquisition, pending actions and disconnection must not dispatch");
}
{
    const { c, calls } = controller();
    c.powerProfile = { available: false, profiles: [{ name: "balanced" }],
        battery_aware: true, actions: [{ name: "test-action" }] };
    c.setBatteryAware(false);
    c.setPowerActionEnabled("test-action", false);
    c.setPowerProfile("balanced");
    assert.equal(calls.length, 0, "unavailable profile service must never receive effects");
    c.powerProfile.available = true;
    c.setPowerProfile("performance");
    c.setPowerActionEnabled("unknown", false);
    c.setPowerProfile("balanced");
    assert.deepEqual(calls[0], { method: "setPowerProfile", args: ["balanced"] });
}
{
    const { c, calls } = controller();
    c.applyPowerProfile({ available: true, battery_automation: { status: "paused" } });
    c.resumeAutomaticProfiles();
    assert.equal(calls.at(-1).method, "resumeAutomaticProfiles");
}
{
    const { c, calls } = controller();
    c.applyBattery(state([], { policy: { warning_percent: 35, critical_percent: 10,
        warning_profile: "balanced", critical_profile: "power-saver", notify_warning: true, notify_critical: true } }));
    c.applyPowerProfile({ available: false, profiles: [] });
    c.updateLevelEnabled("low", false);
    c.settingsOperationFinished("alert");
    c.updateLevelEnabled("low", true);
    assert.equal(c.draftWarningProfile, "keep-current", "cannot enable unavailable profiles");
    assert.equal(calls.at(-1).args[0].notify_warning, true, "notifications work without a profile service");
}
{
    const { c } = controller();
    c.powerSuspend = { available: true, can_suspend: "yes", inhibitors: [] };
    c.powerSuspendAction("suspend");
    c.operationFailed("power-suspend-suspend-1", "Screen lock was not confirmed");
    assert.equal(c.powerSuspendAction(c.suspendRetryAction), true, "failed commands can be retried explicitly");
    c.operationFinished("power-suspend-suspend-2");
    c.sendSucceeds = false;
    c.powerSuspendAction("lock");
    assert.equal(c.actionInFlight, false, "synchronous rejection cannot leave the controls busy");
    c.sendSucceeds = true;
    c.powerSuspendAction("suspend");
    c.transportFailed("Transport closed");
    assert.match(c.suspendError, /may already have been accepted/);
}
{
    const { c, calls } = controller();
    const policy = { same_profile: false,
        battery: { sleep_minutes: 15, hibernate_minutes: 60 },
        plugged: { sleep_minutes: 45, hibernate_minutes: 180 } };
    const state = { available: true, policy, active_profile: "battery" };
    c.applySuspendPolicy(state);
    c.updateSuspendPolicy("", "same_profile", true);
    assert.equal(c.updateSuspendPolicy("battery", "sleep_minutes", 30), false, "pending save prevents duplicate writes");
    assert.equal(calls[0].args[0].plugged.hibernate_minutes, 180, "shared mode retains the separate AC profile");
    c.applySuspendPolicy(state);
    assert.equal(c.suspendPolicyDraft.same_profile, true, "stale telemetry must not overwrite an in-flight edit");
    c.suspendPolicyFailed("hypridle restart failed");
    c.saveSuspendPolicy(); // The acknowledged retry below must retain the edited policy.
    c.suspendPolicyFinished();
    c.applySuspendPolicy({ ...state, policy: calls[1].args[0] });
    assert.equal(c.updateSuspendPolicy("", "lid_action", "shutdown"), false);
    for (const value of [-1, 1.5, 10081, NaN])
        assert.equal(c.updateSuspendPolicy("battery", "sleep_minutes", value), false);
    c.updateSuspendPolicy("battery", "sleep_minutes", 0);
    c.transportFailed("disconnected");
    assert.match(c.suspendPolicyError, /may have been saved/);
    c.suspendPolicyState.available = false;
    assert.equal(c.saveSuspendPolicy(), false, "unmanaged integration never claims settings were applied");
}

// Connectivity errors expire only after a successful snapshot; effect errors
// must remain visible because telemetry cannot acknowledge a lost operation.
for (const operation of ["none", "effect", "threshold", "alert"]) {
    const { c } = controller();
    c.actionInFlight = operation === "effect";
    c.thresholdOperationActive = operation === "threshold";
    c.alertOperationActive = operation === "alert";
    c.transportFailed("connection lost");
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
{
    const { c, calls } = controller();
    c.suspendPolicyState = { available: true, critical_battery: { phase: "armed" } };
    for (const [field, value] of [["percent", 0], ["percent", 21], ["grace_seconds", 0], ["grace_seconds", 301], ["enabled", "yes"]])
        assert.equal(c.updateSuspendPolicy("critical_battery", field, value), false);
    c.updateSuspendPolicy("critical_battery", "enabled", true);
    assert.equal(calls[0].method, "setCriticalPolicy");
    assert.equal(calls[0].args[0].enabled, true);
    c.suspendPolicyFinished();
    c.suspendPolicyState.available = false;
    assert.equal(c.updateSuspendPolicy("critical_battery", "enabled", false), true, "critical protection can be disabled without working idle integration");
    c.suspendPolicyFinished();
    assert.equal(c.cancelCriticalBattery(), false);
    c.suspendPolicyState.critical_battery.phase = "countdown";
    c.cancelCriticalBattery();
    assert.equal(calls.at(-1).method, "cancelCriticalBattery");
}
console.log("battery controls: selection, auto-save, command guards, policy writes and failure recovery passed");
