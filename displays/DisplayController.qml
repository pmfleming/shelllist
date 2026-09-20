import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: controller

    property var displayPolicyState: ({ available: false })
    property bool stateReady: false
    property string displayPolicyError: ""
    property string pendingAction: ""
    property bool revertOnArrival: false
    readonly property bool displayPolicySaving: actionInFlight
    readonly property var trial: (displayPolicyState.layout || {}).trial || null
    readonly property DisplayBackend backend: displayBackend
    readonly property bool canChange: stateReady && displayPolicyState.available && backend.ready && !actionInFlight && !trial
    navigationPrimaryEnabled: false
    navigationBlocked: actionInFlight || !!trial

    function applyDisplayPolicy(value: var): void {
        displayPolicyState = value || ({ available: false });
        stateReady = true;
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
        return canChange && send("policy", { prefer_external: value });
    }
    function displayLayoutAction(action: string, params: var): bool {
        if (!["preview", "confirm", "revert"].includes(action) || !stateReady || !displayPolicyState.available)
            return false;
        if (action === "preview" ? !canChange : (!trial || params.id !== trial.id))
            return false;
        return send(action, params);
    }
    function requestFinished(id: string): void {
        if (!id.startsWith("display-snapshot-")) {
            actionInFlight = false;
            pendingAction = "";
        }
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
            displayLayoutAction("revert", { id: trial.id });
        }
    }
    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        refresh();
    }
    function deactivateUi() {
        revertOnArrival = !!trial || pendingAction === "preview";
        settleHiddenTrial();
        deactivateUiState();
    }
    function dismissNavigation(): bool {
        if (trial) {
            displayLayoutAction("revert", { id: trial.id });
            return true;
        }
        return dismissNavigationHelp() || dismissDetailsOrWindow();
    }

    DisplayBackend {
        id: displayBackend
        controller: controller
    }
}
