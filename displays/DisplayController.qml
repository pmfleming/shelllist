import QtQuick
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Ui.ProviderChooserController {
    id: controller

    sharedScreenshotEnabled: true
    sharedScreenshotStartMessage: "Capturing Displays window…"

    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.globalSettingsOpen ? "display-global-settings" : controller.selectedResult ? controller.selectedResult.key : ""
        tab: controller.detailsTab
        tabs: controller.globalSettingsOpen ? ["focus"] : ["settings", "information"]
        onRestoreRequested: function (open, tab) {
            controller.detailsTab = tab;
            if (!controller.changingDetailsContext)
                controller.detailsOpen = open && (controller.globalSettingsOpen || controller.hasSelection);
        }
    }
    property var displayPolicyState: ({
            available: false
        })
    property var workspaceState: ({available: false})
    property bool stateReady: false
    property string displayPolicyError: ""
    property string pendingAction: ""
    property string observedTrialId: ""
    property bool revertOnArrival: false
    property var draft: []
    property var baselineDraft: []
    property string baselineFingerprint: ""
    property string baselineTopology: ""
    property bool baselinePreference: false
    property bool stale: false
    readonly property string selectedName: selectedResult ? selectedResult.id : ""
    property string referenceName: ""
    property bool discardPrompt: false
    property bool identifyActive: false
    property string identifyName: ""
    property bool changingDetailsContext: false
    property bool globalSettingsOpen: false
    property string detailsTab: "settings"
    property bool arrangementOpen: false
    readonly property DisplayProvider displayProvider: DisplayProvider {
        controller: controller
    }
    property bool layoutDragging: false
    property double clock: Date.now()
    readonly property var outputs: Model.outputs(displayPolicyState)
    readonly property var trial: (displayPolicyState.layout || {}).trial || null
    readonly property DisplayBackend backend: displayBackend
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(baselineDraft)
    readonly property bool canChange: stateReady && displayPolicyState.available && backend.ready && !actionInFlight && !trial
    readonly property bool canEdit: canChange && !stale
    readonly property bool canSetPolicy: canChange && !dirty
    readonly property var focusState: displayPolicyState.focus || ({available: false})
    readonly property bool canSetFocus: canSetPolicy && !!focusState.available
    readonly property string validationError: Model.validate(draft, outputs)
    readonly property bool canPreview: canEdit && dirty && validationError.length === 0
    readonly property var selectedOutput: outputs.find(function (o) {
        return o.name === selectedName;
    }) || null
    readonly property var selectedDraft: draft.find(function (o) {
        return o.name === selectedName;
    }) || null
    readonly property int selectedNumber: outputs.findIndex(function (o) {
        return o.name === selectedName;
    }) + 1
    readonly property int activeCount: outputs.filter(function (o) {
        return !o.disabled;
    }).length
    readonly property int secondsLeft: trial ? Math.max(0, Math.ceil(trial.expires_at - clock / 1000)) : 0
    readonly property string statusMessage: displayPolicyError || displayPolicyState.error || (!stateReady ? qsTr("Connecting…") : !displayPolicyState.available ? qsTr("Enable programs.shelllist.displays.enable to manage displays") : stale ? qsTr("Displays changed · reload the layout") : dirty && validationError ? validationError : displayPolicyState.status === "settling" ? qsTr("Waiting for external display…") : "")

    navigationPrimaryEnabled: false
    provider: displayProvider
    navigationBlocked: discardPrompt || layoutDragging || actionInFlight || !!trial
    onSelectedNameChanged: updateReference()

    signal editorFocusRequested
    signal compactFocusRequested

    function reloadDraft(): void {
        if (actionInFlight || trial)
            return;
        baselineDraft = Model.draft(outputs);
        draft = Model.draft(outputs);
        baselineFingerprint = Model.fingerprint(outputs);
        baselineTopology = Model.topology(outputs);
        baselinePreference = !!(displayPolicyState.policy || {}).prefer_external;
        stale = false;
        discardPrompt = false;
        updateReference();
    }
    function applyDisplayPolicy(value: var): void {
        const previousTrial = observedTrialId;
        displayPolicyState = Object.assign({}, value || ({
                available: false
            }));
        replaceProviderResults(displayProvider.resultsFor(outputs), false);
        observedTrialId = trial ? trial.id : "";
        if (!trial && pendingAction !== "preview")
            revertOnArrival = false;
        stateReady = true;
        clock = Date.now();
        if (trial) {
            if (baselineTopology && Model.topology(outputs) !== baselineTopology)
                stale = true;
        } else if (previousTrial || (!dirty && pendingAction !== "preview")) {
            // A trial ended authoritatively; the new observed layout is the baseline.
            baselineDraft = [];
            draft = [];
            if (!actionInFlight)
                reloadDraft();
        } else if (pendingAction !== "preview" && (Model.fingerprint(outputs) !== baselineFingerprint || !!(displayPolicyState.policy || {}).prefer_external !== baselinePreference)) {
            stale = true;
        }
        settleHiddenTrial();
    }
    function refresh(): void {
        if (backend.ready)
            backend.snapshot();
    }
    function send(action: string, params: var): bool {
        if (!backend.ready || actionInFlight)
            return false;
        actionInFlight = true;
        pendingAction = action;
        displayPolicyError = "";
        if (backend.mutate(action, params))
            return true;
        requestFailed("display-" + action + "-", "Unable to send display request");
        return false;
    }
    function setPreferExternal(value: bool): bool {
        return canSetPolicy && send("policy", {
            prefer_external: value
        });
    }
    function setFocusSetting(key: string, value: var): bool {
        if (!canSetFocus || (focusState.values || {})[key] === undefined)
            return false;
        const values = {};
        values[key] = value;
        return send("focus", {values: values});
    }
    function resetFocusSettings(): bool {
        return canSetFocus && Object.keys(focusState.saved || {}).length > 0 && send("focusReset", {});
    }
    function displayLayoutAction(action: string, params: var): bool {
        if (!["preview", "confirm", "revert"].includes(action) || !stateReady || !displayPolicyState.available)
            return false;
        if (action === "preview" ? !canPreview : (!trial || params.id !== trial.id))
            return false;
        if (action === "confirm" && (stale || secondsLeft <= 0))
            return false;
        return send(action, params);
    }
    function preview(): bool {
        return displayLayoutAction("preview", {
            outputs: Model.payload(draft)
        });
    }
    function canToggleEnabled(name: string): bool {
        const output = draft.find(o => o.name === name);
        return canEdit && !!output && (!output.enabled || draft.some(o => o.name !== name && o.enabled));
    }
    function setDisplayContent(name: string, source: string): void {
        const output = draft.find(o => o.name === name);
        if (!canEdit || !output || !output.enabled)
            return;
        if (!source) {
            draft = Model.extend(draft, name);
        } else if (Model.mirrorSources(draft, name).some(o => o.name === source)) {
            draft = draft.map(o => o.name === name ? Object.assign({}, o, {mirror_of: source}) : o);
        }
        updateReference();
    }
    function edit(name: string, key: string, value: var): void {
        if (!canEdit || !["mode", "x", "y", "scale", "transform", "enabled"].includes(key))
            return;
        if (key === "enabled") {
            if (value === false && !canToggleEnabled(name))
                return;
            draft = Model.setEnabled(draft, name, value);
            return;
        }
        if (["x", "y"].includes(key) && draft.some(o => o.name === name && !!o.mirror_of))
            return;
        const normalized = ["x", "y", "scale", "transform"].includes(key) && Model.number(value) ? Number(value) : value;
        draft = draft.map(o => o.name === name ? Object.assign({}, o, {[key]: normalized}) : o);
    }
    function moveTo(name: string, x: real, y: real, snapDistance: real): void {
        if (!canEdit || draft.some(o => o.name === name && !!o.mirror_of))
            return;
        const position = Model.snap(draft, name, x, y, snapDistance);
        draft = draft.map(function (o) {
            return o.name === name ? Object.assign({}, o, {
                x: Math.round(position.x),
                y: Math.round(position.y)
            }) : o;
        });
    }
    function moveSelected(dx: real, dy: real): void {
        if (selectedDraft)
            moveTo(selectedName, Number(selectedDraft.x) + dx, Number(selectedDraft.y) + dy, 0);
    }
    function placeSelected(side: string): void {
        const reference = draft.find(function (o) {
            return o.name === referenceName;
        });
        if (!selectedDraft || selectedDraft.mirror_of || !reference || reference.mirror_of || !["left", "right", "above", "below"].includes(side))
            return;
        const position = Model.adjacent(selectedDraft, reference, side);
        moveTo(selectedName, position.x, position.y, 0);
    }
    function updateReference(): void {
        if (!draft.some(function (o) {
            return o.name === referenceName && o.name !== selectedName && !o.mirror_of;
        }))
            referenceName = (draft.find(function (o) {
                    return o.name !== selectedName && !o.mirror_of;
                }) || {}).name || "";
    }
    function selectOutput(name: string): void {
        if (!outputs.some(function (o) {
            return o.name === name;
        }))
            return;
        if (!filteredResults.some(function (result) {
            return result.id === name;
        }))
            filterText = "";
        const index = filteredResults.findIndex(function (result) {
            return result.id === name;
        });
        if (index >= 0)
            selectedIndex = index;
        updateReference();
    }
    function triggerDetailAction(actionId): bool {
        return !navigationBlocked && executeSelected(actionId);
    }
    function cycleDetailsTab(backwards: bool): void {
        if (globalSettingsOpen)
            return;
        const tabs = ["settings", "information"];
        detailsTab = tabAfter(tabs, detailsTab, backwards);
    }
    function cycleOutput(delta: int): void {
        if (!outputs.length)
            return;
        selectOutput(outputs[(Math.max(0, selectedNumber - 1) + delta + outputs.length) % outputs.length].name);
    }
    function openGlobalSettings(): void {
        if (navigationBlocked)
            return;
        viewMemory.synchronize();
        changingDetailsContext = true;
        globalSettingsOpen = true;
        viewMemory.synchronize();
        changingDetailsContext = false;
        detailsTab = "focus";
        detailsOpen = true;
        focusDetailsRequested();
    }
    function openDetails() {
        if (!hasSelection || navigationBlocked)
            return;
        viewMemory.synchronize();
        changingDetailsContext = true;
        globalSettingsOpen = false;
        viewMemory.synchronize();
        changingDetailsContext = false;
        detailsOpen = true;
    }
    function closeDetails() {
        viewMemory.synchronize();
        if (trial || actionInFlight)
            return;
        if (dirty) {
            discardPrompt = true;
            return;
        }
        detailsOpen = false;
        compactFocusRequested();
        focusSearchRequested();
    }
    function discardAndClose(): void {
        reloadDraft();
        detailsOpen = false;
        compactFocusRequested();
        focusSearchRequested();
    }
    function executeOutputAction(actionId: string, name: string): bool {
        if (!outputs.some(function (output) {
            return output.name === name;
        }))
            return false;
        if (actionId === "preview")
            return preview();
        selectOutput(name);
        if (actionId === "identify") {
            identifyName = name;
            identifyActive = true;
            identifyTimer.restart();
            return true;
        }
        if (actionId === "arrange") {
            detailsTab = "settings";
            arrangementOpen = true;
            openDetails();
            Qt.callLater(editorFocusRequested);
            return true;
        }
        if (actionId === "toggle-enabled" && selectedDraft && canToggleEnabled(name)) {
            edit(name, "enabled", !selectedDraft.enabled);
            return true;
        }
        return false;
    }
    function identify(): void {
        identifyName = "";
        identifyActive = true;
        identifyTimer.restart();
    }
    function requestFinished(id: string): void {
        if (!id.startsWith("display-snapshot-")) {
            actionInFlight = false;
            pendingAction = "";
        }
        if (!trial && !dirty)
            reloadDraft();
        displayPolicyError = "";
        settleHiddenTrial();
    }
    function requestFailed(id: string, message: string): void {
        if (!id.startsWith("display-snapshot-")) {
            actionInFlight = false;
            pendingAction = "";
        }
        displayPolicyError = message;
    }
    function transportFailed(message: string): void {
        workspaceState = ({available: false});
        stateReady = false;
        actionInFlight = false;
        pendingAction = "";
        displayPolicyError = message;
    }
    function settleHiddenTrial(): void {
        if (revertOnArrival && trial && !actionInFlight && backend.ready) {
            revertOnArrival = false;
            displayLayoutAction("revert", {
                id: trial.id
            });
        }
    }
    function activateUi(workspaceId) {
        stateReady = false;
        activateUiState(workspaceId);
        refresh();
    }
    function deactivateUi() {
        identifyActive = false;
        revertOnArrival = !!trial || pendingAction === "preview";
        settleHiddenTrial();
        deactivateUiState();
    }
    function dismissNavigation(): bool {
        if (discardPrompt) {
            discardPrompt = false;
            editorFocusRequested();
            return true;
        }
        if (trial) {
            displayLayoutAction("revert", {
                id: trial.id
            });
            return true;
        }
        if (actionInFlight)
            return true;
        return dismissDetailsOrWindow();
    }

    Timer {
        id: identifyTimer
        interval: 3000
        onTriggered: controller.identifyActive = false
    }
    Timer {
        interval: 250
        repeat: true
        running: controller.uiActive && !!controller.trial
        onTriggered: controller.clock = Date.now()
    }
    DisplayBackend {
        id: displayBackend
        controller: controller
    }
}
