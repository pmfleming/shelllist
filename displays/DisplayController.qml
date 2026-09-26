import QtQuick
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Ui.ProviderChooserController {
    id: controller

    property var displayPolicyState: ({
            available: false
        })
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
    // Use the common expansion animation, but clamp both widths to this output.
    closedWidthFraction: 1
    openWidthFraction: 1
    minimumClosedWindowWidth: Math.min(Ui.Theme.popupClosedWidth, availableScreenWidth || Ui.Theme.popupClosedWidth)
    minimumOpenWindowWidth: Math.min(Ui.Theme.popupOpenWidth, availableScreenWidth || Ui.Theme.popupOpenWidth)

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
        replaceProviderResults(displayProvider.resultsForOutputs(outputs), false);
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
    function edit(name: string, key: string, value: var): void {
        if (!canEdit || !["mode", "x", "y", "scale", "transform", "enabled"].includes(key))
            return;
        if (key === "enabled" && Model.internal(name))
            return;
        draft = draft.map(function (o) {
            if (o.name !== name)
                return o;
            const next = Object.assign({}, o);
            next[key] = ["x", "y", "scale", "transform"].includes(key) && Model.number(value) ? Number(value) : value;
            return next;
        });
    }
    function moveTo(name: string, x: real, y: real, snapDistance: real): void {
        if (!canEdit)
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
        if (!selectedDraft || !reference || !["left", "right", "above", "below"].includes(side))
            return;
        const position = Model.adjacent(selectedDraft, reference, side);
        moveTo(selectedName, position.x, position.y, 0);
    }
    function updateReference(): void {
        if (!outputs.some(function (o) {
            return o.name === referenceName && o.name !== selectedName;
        }))
            referenceName = (outputs.find(function (o) {
                    return o.name !== selectedName;
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
    function cycleDetailsTab(): void {
        detailsTab = detailsTab === "settings" ? "information" : "settings";
    }
    function cycleOutput(delta: int): void {
        if (!outputs.length)
            return;
        selectOutput(outputs[(Math.max(0, selectedNumber - 1) + delta + outputs.length) % outputs.length].name);
    }
    function openDetails() {
        if (!hasSelection || navigationBlocked)
            return;
        detailsOpen = true;
    }
    function closeDetails() {
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
        if (actionId === "toggle-enabled" && selectedDraft && canEdit) {
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
        return dismissNavigationHelp() || dismissDetailsOrWindow();
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
