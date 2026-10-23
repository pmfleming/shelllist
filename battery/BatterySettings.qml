import QtQuick
import "BatteryFlow.js" as Flow
import "BatteryFeedback.js" as Presentation

// Saved field drafts and their acknowledgement fences, not field-local editors.
// Suspend/critical protection and interactive operation ownership stay outside.
Item {
    id: settings
    required property BatteryBackend backend
    property bool actionInFlight: false
    property bool batteryOperationActive: false
    property bool protectionSupported: false
    property var selectedDevice: null
    property var protection: ({})
    property var policy: ({})
    property var levelProfileOptions: []
    signal statusMessage(string message)

    property bool draftProtectionEnabled: false
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property var alertDraft: Flow.alertDraft({})
    property var lastLevelProfiles: ({low: "power-saver", critical: "power-saver"})
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false
    property bool thresholdEditing: false
    property bool alertEditing: false
    property bool thresholdOperationActive: false
    property bool alertOperationActive: false
    property int thresholdRevision: 0
    property int thresholdSentRevision: 0
    property int protectionRevision: 0
    property int protectionAcknowledgedRevision: 0
    property int protectionSentRevision: 0
    property int alertRevision: 0
    property int alertSentRevision: 0
    property string thresholdSaveError: ""
    property string alertSaveError: ""
    // Only a newer user revision or an explicit flush can retry uncertainty.
    property int thresholdFailedRevision: -1
    property int alertFailedRevision: -1
    readonly property bool thresholdDraftValid: Flow.thresholdRangeValid(draftStartPercent, draftEndPercent)
    readonly property bool alertDraftValid: Flow.alertRangeValid(alertDraft.warning_percent, alertDraft.critical_percent)
    readonly property bool operationActive: thresholdOperationActive || alertOperationActive
    readonly property string error: thresholdSaveError || alertSaveError
    readonly property string thresholdSaveStatus: Presentation.saveStatus(thresholdDraftValid, "Choose a valid range", thresholdOperationActive, thresholdSaveError, thresholdDraftDirty)
    readonly property string alertSaveStatus: Presentation.saveStatus(alertDraftValid, "Choose valid battery levels", alertOperationActive, alertSaveError, alertDraftDirty)
    readonly property var levelFields: Flow.levelFields

    function resetSelection(): void {
        thresholdAutoSave.stop();
        thresholdDraftDirty = false;
        thresholdEditing = false;
        thresholdSaveError = "";
        thresholdRevision += 1;
        protectionAcknowledgedRevision = protectionRevision;
        protectionSentRevision = protectionRevision;
    }
    function syncThresholdDraft(): void {
        if (thresholdDraftDirty) return;
        draftProtectionEnabled = !!protection.desired_enabled;
        draftStartPercent = Number(Flow.valueOr(protection.desired_start_percent, 75));
        draftEndPercent = Number(Flow.valueOr(protection.desired_end_percent, 80));
    }
    function syncDrafts(): void {
        syncThresholdDraft();
        if (!alertDraftDirty) alertDraft = Flow.alertDraft(policy);
    }
    function resume(): void {
        scheduleThresholdSave(false);
        finishAlertEditingIfIdle();
    }
    function finished(domain: string): void {
        if (domain === "threshold") {
            thresholdOperationActive = false;
            thresholdSaveError = "";
            protectionAcknowledgedRevision = protectionSentRevision;
            if (thresholdRevision === thresholdSentRevision) thresholdDraftDirty = false;
            else scheduleThresholdSave(false);
        } else {
            alertOperationActive = false;
            alertSaveError = "";
            if (alertRevision === alertSentRevision) alertDraftDirty = false;
            else finishAlertEditingIfIdle();
        }
        statusMessage(error);
    }
    function failed(domain: string, message: string): void {
        statusMessage(message);
        if (domain === "threshold") {
            thresholdOperationActive = false;
            thresholdSaveError = message;
            thresholdFailedRevision = thresholdSentRevision;
            if (thresholdRevision !== thresholdSentRevision) scheduleThresholdSave(false);
        } else {
            alertOperationActive = false;
            alertSaveError = message;
            alertFailedRevision = alertSentRevision;
            if (alertRevision !== alertSentRevision) finishAlertEditingIfIdle();
        }
    }
    function stop(): void { thresholdAutoSave.stop(); alertAutoSave.stop(); }
    function transportFailed(message: string): void {
        if (thresholdOperationActive) {
            thresholdOperationActive = false;
            thresholdSaveError = message;
            thresholdFailedRevision = thresholdSentRevision;
        }
        if (alertOperationActive) {
            alertOperationActive = false;
            alertSaveError = message;
            alertFailedRevision = alertSentRevision;
        }
    }
    function scheduleThresholdSave(immediate: bool): void {
        thresholdAutoSave.stop();
        if (thresholdEditing || !thresholdDraftValid || !thresholdDraftDirty || thresholdRevision <= thresholdFailedRevision) return;
        if (immediate) flushThresholdPolicy();
        else thresholdAutoSave.restart();
    }
    function markThresholdChanged(immediate: bool): void {
        thresholdRevision += 1;
        thresholdDraftDirty = true;
        thresholdSaveError = "";
        scheduleThresholdSave(immediate);
    }
    function updateStartPercent(value: int, dragging: bool): void {
        if (!Flow.thresholdRangeValid(value, draftEndPercent)) return;
        thresholdEditing = dragging;
        draftStartPercent = value;
        markThresholdChanged(false);
    }
    function updateEndPercent(value: int, dragging: bool): void {
        if (!Flow.thresholdRangeValid(draftStartPercent, value)) return;
        thresholdEditing = dragging;
        draftEndPercent = value;
        markThresholdChanged(false);
    }
    function markAlertChanged(immediate: bool): void {
        alertRevision += 1;
        alertDraftDirty = true;
        alertSaveError = "";
        alertAutoSave.stop();
        if (alertEditing || !alertDraftValid) return;
        if (immediate) flushAlertPolicy();
        else alertAutoSave.restart();
    }
    function editAlert(changes: var, immediate: bool): void {
        alertDraft = Object.assign({}, alertDraft, changes);
        markAlertChanged(immediate);
    }
    function updateWarningPercent(value: int, dragging: bool): void {
        alertEditing = dragging;
        editAlert({warning_percent: value}, false);
    }
    function updateCriticalPercent(value: int, dragging: bool): void {
        alertEditing = dragging;
        editAlert({critical_percent: value}, false);
    }
    function finishAlertEditing(): void {
        alertEditing = false;
        finishAlertEditingIfIdle();
    }
    function finishAlertEditingIfIdle(): void {
        if (!alertEditing && alertDraftValid && alertDraftDirty && alertRevision > alertFailedRevision) alertAutoSave.restart();
    }
    function updateNotifyWhenFull(value: bool): void { editAlert({notify_when_full: value}, true); }
    function updateLevelEnabled(level: string, enabled: bool): void {
        const fields = levelFields[level];
        if (actionInFlight || !fields) return;
        const current = alertDraft[fields.profile];
        if (current !== "keep-current") lastLevelProfiles = Object.assign({}, lastLevelProfiles, {[level]: current});
        const previous = lastLevelProfiles[level];
        const option = levelProfileOptions.find(option => option.value === previous && option.enabled)
            || levelProfileOptions.find(option => option.enabled);
        // Notification settings remain usable without a power-profile service.
        const profile = enabled && option ? option.value : "keep-current";
        editAlert({[fields.notify]: enabled, [fields.profile]: profile}, true);
    }
    function updateLevelProfile(level: string, value: string): void {
        const fields = levelFields[level];
        if (!fields || (value !== "keep-current" && !levelProfileOptions.some(option => option.value === value && option.enabled !== false))) return;
        editAlert({[fields.profile]: value}, true);
    }
    function setProtection(enabled: bool): bool {
        if (actionInFlight || batteryOperationActive || !protectionSupported || !selectedDevice) return false;
        draftProtectionEnabled = enabled;
        protectionRevision += 1;
        markThresholdChanged(true);
        return true;
    }
    function flushThresholdPolicy(): bool {
        if (thresholdEditing || thresholdOperationActive || actionInFlight || batteryOperationActive || !protectionSupported || !thresholdDraftValid || !thresholdDraftDirty || !selectedDevice) return false;
        thresholdSentRevision = thresholdRevision;
        protectionSentRevision = protectionRevision;
        thresholdOperationActive = true;
        thresholdSaveError = "";
        statusMessage("");
        const started = protectionRevision !== protectionAcknowledgedRevision
            ? backend.setProtection(selectedDevice.id, draftProtectionEnabled, draftStartPercent, draftEndPercent)
            : backend.setThresholds(selectedDevice.id, draftStartPercent, draftEndPercent);
        if (started) return true;
        thresholdOperationActive = false;
        thresholdSaveError = "Unable to send the battery protection policy";
        statusMessage(thresholdSaveError);
        return false;
    }
    function flushAlertPolicy(): bool {
        if (alertEditing || alertOperationActive || actionInFlight || !alertDraftValid || !alertDraftDirty) return false;
        alertSentRevision = alertRevision;
        alertOperationActive = true;
        alertSaveError = "";
        statusMessage("");
        if (backend.setAlertPolicy(alertDraft)) return true;
        alertOperationActive = false;
        alertSaveError = "Unable to send battery levels & actions";
        statusMessage(alertSaveError);
        return false;
    }
    Timer {
        id: thresholdAutoSave
        interval: 500
        onTriggered: if (settings.thresholdRevision > settings.thresholdFailedRevision) settings.flushThresholdPolicy()
    }
    Timer {
        id: alertAutoSave
        interval: 500
        onTriggered: if (settings.alertRevision > settings.alertFailedRevision) settings.flushAlertPolicy()
    }
}
