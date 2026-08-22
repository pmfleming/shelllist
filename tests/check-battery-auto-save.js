#!/usr/bin/env node
const fs = require("fs");

const [controllerPath, backendPath, panePath] = process.argv.slice(2);
const controller = fs.readFileSync(controllerPath, "utf8");
const backend = fs.readFileSync(backendPath, "utf8");
const pane = fs.readFileSync(panePath, "utf8");

function requireMatch(source, pattern, message) {
    if (!pattern.test(source))
        throw new Error(message);
}

function rejectMatch(source, pattern, message) {
    if (pattern.test(source))
        throw new Error(message);
}

rejectMatch(pane, /Apply thresholds|Save alert policy|Thresholds saved|Alert policy saved/,
    "battery settings must not expose save/apply controls");
rejectMatch(controller, /function applyThresholds|function applyAlertPolicy/,
    "battery settings must not retain manual apply handlers");
requireMatch(pane, /onEditingFinished: pane\.controller\.finishThresholdEditing\(\)/,
    "threshold sliders must apply after editing finishes");
requireMatch(pane, /onEditingFinished: pane\.controller\.finishAlertEditing\(\)/,
    "alert sliders must apply after editing finishes");
requireMatch(controller, /id: thresholdAutoSave\s+interval: 500/,
    "threshold changes must use the controlled debounce");
requireMatch(controller, /id: alertAutoSave\s+interval: 500/,
    "alert changes must use the controlled debounce");
requireMatch(controller,
    /backend\.setProtection\(selectedDevice\.id, draftProtectionEnabled,\s+draftStartPercent, draftEndPercent\)/,
    "protection state and draft thresholds must be submitted atomically");
requireMatch(controller,
    /: backend\.setThresholds\(selectedDevice\.id, draftStartPercent, draftEndPercent\)/,
    "range-only edits must preserve the current protection and management state");
requireMatch(backend, /start_percent: startPercent,\s+end_percent: endPercent/,
    "the protection request must carry both threshold values");
requireMatch(controller, /thresholdRevision !== thresholdSentRevision/,
    "new threshold edits must be retained after an in-flight request");
requireMatch(controller, /alertRevision !== alertSentRevision/,
    "new alert edits must be retained after an in-flight request");
requireMatch(pane, /thresholdSaveStatus/, "threshold auto-apply state must be visible");
requireMatch(pane, /alertSaveStatus/, "alert auto-apply state must be visible");

console.log("battery auto-save: no-save policy and coalesced updates passed");
