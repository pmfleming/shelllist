pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Displays as Displays
import Shelllist.Ui as Ui

DaemonTestCase {
    id: testCase
    name: "Displays"
    when: windowShown
    visible: true
    width: 1040
    height: 780

    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            readonly property Item detailsItem: content.detailsItem
            property alias viewport: viewport
            readonly property bool listVisible: content.listItem.visible
            Displays.DisplayController {
                id: controller
                availableScreenWidth: panel.width
                availableScreenHeight: panel.height
            }
            Ui.SurfaceViewport {
                id: viewport
                width: Math.min(panel.width, controller.currentWindowWidth)
                height: panel.height
                canvasWidth: controller.currentWindowWidth
                Displays.DisplayContent { id: content; controller: panel.controller }
            }
        }
    }
    function displayState() {
        return { available: true, policy: { prefer_external: true }, status: "external", layout: { saved: { outputs: [] }, trial: null },
            outputs: [{ id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: true, availableModes: ["1920x1200@60.00Hz"] },
                { id: 1, name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, availableModes: ["3840x2160@60.00Hz"] }] };
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applyDisplayPolicy(displayState());
        verify(waitForRendering(panel));
        calls = [];
        return panel;
    }
    function waitForDetails(panel) {
        // The asynchronous Loader exposes children before their bindings and
        // nested Repeaters finish initializing. Object names alone aren't ready signals.
        tryVerify(function () { return panel.detailsItem !== null; });
        tryCompare(panel.detailsItem.parent, "status", Loader.Ready);
        verify(waitForPolish(panel.Window.window));
    }
    function focusState() {
        const state = displayState();
        state.outputs[0].disabled = false;
        state.outputs[0].focused = false;
        state.outputs[1].focused = true;
        state.focus = { available: true, error: null, saved: {}, values: {
            "input:follow_mouse": 1, "misc:mouse_move_focuses_monitor": true,
            "cursor:no_warps": false, "input:follow_mouse_threshold": 0
        } };
        return state;
    }
    function test_editsNormalizeOnlyTheTargetAndRetainInvalidInput() {
        const c = makePanel().controller;
        const untouched = c.draft[0];
        for (const field of ["x", "y", "scale", "transform"]) {
            c.edit("DP-1", field, "2");
            compare(c.draft[1][field], 2);
            compare(c.draft[0], untouched);
        }
        c.edit("DP-1", "scale", "");
        compare(c.draft[1].scale, "", "invalid input remains available for validation");
        c.edit("DP-1", "mode", "3840x2160@60.00Hz");
        compare(c.draft[1].mode, "3840x2160@60.00Hz");
        const before = JSON.stringify(c.draft);
        c.edit("missing", "scale", 3);
        c.edit("DP-1", "unknown-field", 3);
        compare(JSON.stringify(c.draft), before);
        compare(calls.length, 0, "edits never bypass preview");
    }
    function test_focusTelemetryDoesNotInvalidateLayoutDrafts() {
        const panel = makePanel();
        const c = panel.controller;
        c.applyDisplayPolicy(focusState());
        c.openDetails();
        c.detailsTab = "focus";
        waitForDetails(panel);
        const label = findChild(panel, "displayFocusedMonitor");
        verify(label.text.indexOf("DP-1") >= 0);
        c.edit("DP-1", "scale", 2);
        const switched = focusState();
        switched.outputs[0].focused = true;
        switched.outputs[1].focused = false;
        c.applyDisplayPolicy(switched);
        verify(label.text.indexOf("eDP-1") >= 0);
        verify(c.dirty && !c.stale);
        verify(c.canPreview);
        c.backend.applyData({workspaces: {available: true, focused_monitor: "DP-1",
            active_window: {title: "Editor", workspace_id: 1}, workspaces: [{id: 1, monitor: "eDP-1"}]}});
        verify(label.text.indexOf("DP-1") >= 0);
        verify(findChild(panel, "displayFocusedWindow").text.indexOf("Editor · Monitor: eDP-1") >= 0,
            "active monitor and focused-window monitor may differ");
        verify(c.dirty && !c.stale);
        compare(calls.length, 0);
    }
    function test_focusSettingsAreGlobalAcknowledgedAndRetryable() {
        const panel = makePanel();
        const c = panel.controller;
        c.applyDisplayPolicy(focusState());
        c.openDetails();
        c.cycleDetailsTab();
        compare(c.detailsTab, "focus");
        waitForDetails(panel);
        const choice = findChild(panel, "focusSetting-misc:mouse_move_focuses_monitor");
        verify(choice !== null && choice.interactive);
        compare(choice.value, "true");
        choice.selected("false");
        compare(calls.length, 1);
        compare(calls[0].method, "displayFocus.set");
        compare(calls[0].params.values["misc:mouse_move_focuses_monitor"], false);
        compare(Object.keys(calls[0].params.values).length, 1, "only the chosen setting is overridden");
        compare(choice.value, "true", "no optimistic setting change");
        verify(!choice.interactive);
        c.requestFailed(calls[0].id, "compositor refused focus settings");
        verify(choice.interactive);
        compare(choice.value, "true");
        choice.selected("false");
        const saved = focusState();
        saved.focus.values["misc:mouse_move_focuses_monitor"] = false;
        saved.focus.saved["misc:mouse_move_focuses_monitor"] = false;
        c.applyDisplayPolicy(saved);
        c.requestFinished(calls[1].id);
        compare(choice.value, "false");
        verify(!c.dirty, "focus settings are not layout drafts");
        c.selectOutput("eDP-1");
        compare(choice.value, "false", "changing selection does not change global focus settings");
        const unsupported = findChild(panel, "focusSetting-input:focus_on_close");
        verify(!unsupported.interactive);
        verify(!c.setFocusSetting("input:focus_on_close", 1));
        const reset = findChild(panel, "resetDisplayFocus");
        verify(reset.enabled);
        reset.clicked();
        compare(calls[2].method, "displayFocus.reset");
        c.applyDisplayPolicy(focusState());
        c.requestFinished(calls[2].id);
        compare(choice.value, "true");
        verify(!reset.enabled);
        c.cycleDetailsTab();
        compare(c.detailsTab, "information");
        c.cycleDetailsTab();
        compare(c.detailsTab, "settings");
    }
    function test_focusControlsRespectLayoutTrialsDisconnectsAndNumericValidation() {
        const panel = makePanel();
        const c = panel.controller;
        c.applyDisplayPolicy(focusState());
        c.openDetails();
        c.detailsTab = "focus";
        waitForDetails(panel);
        const number = findChild(panel, "focusNumber-input:follow_mouse_threshold");
        number.edited("");
        verify(!number.inputValid);
        number.accepted();
        compare(calls.length, 0);
        number.edited("-1");
        verify(!number.inputValid);
        number.edited("2.5");
        verify(number.inputValid);
        number.accepted();
        compare(calls[0].params.values["input:follow_mouse_threshold"], 2.5);
        c.requestFailed(calls[0].id, "retry");
        c.edit("DP-1", "scale", 2);
        verify(!c.canSetFocus);
        verify(!c.setFocusSetting("input:follow_mouse", 0));
        c.reloadDraft();
        const trial = focusState();
        trial.layout.trial = {id: "token", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(trial);
        verify(!c.canSetFocus);
        c.applyDisplayPolicy(focusState());
        c.transportFailed("disconnected");
        verify(!c.canSetFocus);
        verify(!c.setFocusSetting("input:follow_mouse", 0));
        c.applyDisplayPolicy(focusState());
        verify(c.canSetFocus);
        panel.width = 390;
        panel.height = 600;
        // A rendered frame can precede the nested layout's resize/polish pass.
        verify(waitForPolish(panel.Window.window));
        const page = findChild(panel, "displayFocusPane");
        verify(page.width > 0 && panel.detailsItem.width >= 495 && panel.listVisible, "small outputs retain the split canvas, not a replacement pane");
        verify(panel.viewport.contentWidth > panel.viewport.width);
        number.focusInput(false);
        tryVerify(function () {
            const position = number.mapToItem(page, 0, 0);
            return position.y >= 0 && position.y + number.height <= page.height;
        });
        tryVerify(function () {
            const position = number.mapToItem(panel.viewport, 0, 0);
            return panel.viewport.contentX > 0 && position.x >= 0 && position.x < panel.viewport.width;
        });
    }
    function test_mirrorAndExtendRemainDraftOnlyAndUseTheLayoutPreview() {
        const panel = makePanel();
        const c = panel.controller;
        const state = displayState();
        state.outputs[0].disabled = false;
        c.applyDisplayPolicy(state);
        c.selectOutput("DP-1");
        c.openDetails();
        tryVerify(function () { return findChild(panel, "displayPlace-right") !== null; });
        const content = findChild(panel, "displayContentMode");
        verify(content.interactive);
        content.selected("eDP-1");
        compare(c.selectedDraft.mirror_of, "eDP-1");
        verify(c.canPreview);
        verify(!findChild(panel, "displayPositionCard").enabled);
        const oldX = c.selectedDraft.x;
        c.edit("DP-1", "x", 9999);
        c.moveSelected(16, 0);
        compare(c.selectedDraft.x, oldX, "mirrors cannot be positioned independently");
        c.arrangementOpen = true;
        compare(findChild(panel, "displayWorkspaceCanvas").values.length, 1, "a mirror is not a second desktop tile");
        compare(calls.length, 0);
        content.selected("");
        compare(c.selectedDraft.mirror_of, "");
        verify(findChild(panel, "displayPositionCard").enabled);
        verify(c.selectedDraft.x >= 1536, "extended content gets an independent position");
        content.selected("eDP-1");
        verify(c.preview());
        compare(calls[0].method, "displayLayout.preview");
        compare(calls[0].params.outputs[1].mirror_of, "eDP-1");
        compare(calls[0].params.outputs[0].mirror_of, "");
        const observed = displayState();
        observed.outputs[0].disabled = false;
        observed.outputs[1].mirrorOf = "0";
        observed.outputs[1].x = 0;
        observed.layout.trial = {id: "mirror-trial", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(observed);
        c.requestFinished(calls[0].id);
        verify(!content.interactive);
        verify(c.displayLayoutAction("revert", {id: "mirror-trial"}));
        compare(calls[1].method, "displayLayout.revert");
    }
    function test_disablingMirrorSourcePromotesCopiesAndMirrorTelemetryInvalidatesDrafts() {
        const panel = makePanel();
        const c = panel.controller;
        const state = displayState();
        state.outputs[0].disabled = false;
        state.outputs[1].mirrorOf = "0";
        state.outputs[1].x = 0;
        c.applyDisplayPolicy(state);
        compare(c.draft[1].mirror_of, "eDP-1");
        c.setDisplayContent("eDP-1", "DP-1");
        compare(c.draft[0].mirror_of, "", "cannot mirror a mirror");
        c.edit("eDP-1", "enabled", false);
        verify(!c.draft[0].enabled && c.draft[1].enabled);
        compare(c.draft[1].mirror_of, "", "the survivor becomes independent");
        verify(c.canPreview);
        verify(!c.canToggleEnabled("DP-1"));
        c.reloadDraft();
        c.edit("DP-1", "scale", 2);
        const changed = displayState();
        changed.outputs[0].disabled = false;
        c.applyDisplayPolicy(changed);
        verify(c.stale, "external changes to mirroring invalidate the draft");
        compare(calls.length, 0);
    }
    function test_emptySelectionRetainsBackAndDraftRecovery() {
        const panel = makePanel();
        const c = panel.controller;
        panel.width = 390;
        panel.height = 600;
        c.uiActive = true;
        c.openDetails();
        tryVerify(function () { return findChild(panel, "backToDisplayList") !== null; });
        c.edit("DP-1", "scale", 2);
        const empty = displayState();
        empty.outputs = [];
        c.applyDisplayPolicy(empty);
        verify(c.stale && c.dirty);
        verify(!c.hasSelection);
        verify(findChild(panel, "displayEmptyDetails").visible);
        const back = findChild(panel, "backToDisplayList");
        verify(back.visible && back.enabled);
        back.forceActiveFocus();
        keyClick(Qt.Key_Left);
        verify(c.discardPrompt, "Left/back still protects a disconnected display's draft");
        c.discardAndClose();
        tryVerify(function () { return findChild(panel, "displayList").visible; });
        compare(findChild(panel, "displayList").emptyText, "No connected displays");
        verify(!c.dirty);
        c.applyDisplayPolicy(displayState());
        verify(c.hasSelection);
        c.selectionModel.rankRequestsEnabled = false;
        c.filterText = "unmatched";
        const store = c.selectionModel;
        store.applyRustRanking(store.searchOwner, store.searchGeneration, []);
        compare(findChild(panel, "displayList").emptyText, "No matching displays");
        c.filterText = "";
        verify(c.hasSelection);
    }
    function test_providerResultsAndLiveActions() {
        const c = makePanel().controller;
        const provider = c.displayProvider;
        const results = provider.resultsFor(c.outputs);
        compare(results.length, 2);
        compare(results[0].key, "displays::eDP-1");
        verify(results[0].subtitle.indexOf("Off · External display preferred") >= 0);
        verify(results[1].keywords.indexOf("DP-1") >= 0);
        const internalActions = provider.actionsFor(results[0]);
        verify(internalActions.find(a => a.id === "toggle-enabled").visible);
        verify(internalActions.find(a => a.id === "toggle-enabled").enabled);
        verify(!internalActions.find(a => a.id === "identify").enabled);
        verify(!provider.actionsFor(results[1]).find(a => a.id === "preview").enabled);
        verify(!provider.execute({ result: results[1], actionId: "toggle-enabled" }), "cannot disable the last enabled output");
        c.edit("DP-1", "enabled", false);
        verify(c.draft[1].enabled, "direct edits also protect the last enabled output");
        verify(provider.execute({ result: results[0], actionId: "toggle-enabled" }));
        verify(c.draft[0].enabled, "laptop can be enabled manually");
        verify(provider.execute({ result: results[0], actionId: "toggle-enabled" }));
        verify(!c.draft[0].enabled, "laptop can be disabled while external remains enabled");
        verify(!c.dirty);
        verify(provider.execute({ result: results[0], actionId: "toggle-enabled" }));
        verify(provider.execute({ result: results[1], actionId: "toggle-enabled" }));
        verify(!c.draft[1].enabled, "external can be disabled with laptop enabled");
        verify(!provider.actionsFor(results[0]).find(a => a.id === "toggle-enabled").enabled);
        verify(c.dirty);
        compare(calls.length, 0, "enablement is draft-only");
        verify(provider.actionsFor(results[1]).find(a => a.id === "preview").enabled);
        verify(provider.execute({ result: results[1], actionId: "identify" }));
        compare(c.identifyName, "DP-1");
        verify(c.identifyActive);
        const changed = displayState();
        changed.outputs[1].id = 99;
        c.applyDisplayPolicy(changed);
        compare(provider.actionsFor(results[1]).length, 0, "stale output identity is rejected");
        verify(!provider.execute({ result: results[1], actionId: "toggle-enabled" }));
    }
    function test_dockingChoiceWaitsForAcknowledgementAndCanRetry() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        tryVerify(function () { return findChild(panel, "dockedLaptopBehavior") !== null; });
        verify(waitForRendering(panel));
        const choice = findChild(panel, "dockedLaptopBehavior");
        const status = findChild(panel, "dockingSaveStatus");
        choice.forceActiveFocus();
        keyClick(Qt.Key_Up); // Exercise ComboBox activation, not just the signal.
        compare(calls.length, 1);
        compare(calls[0].method, "displayPolicy.set");
        compare(calls[0].params.prefer_external, false);
        compare(choice.value, "auto-off");
        compare(choice.currentIndex, 1, "do not optimistically display an unacknowledged choice");
        compare(status.text, "Saving preference…");
        verify(!choice.interactive);
        c.requestFailed(calls[0].id, "Could not save preference");
        verify(choice.interactive);
        compare(choice.value, "auto-off");
        compare(choice.currentIndex, 1);
        verify(c.statusMessage.indexOf("Could not save") >= 0);
        choice.forceActiveFocus();
        keyClick(Qt.Key_Up);
        compare(calls.length, 2);
        const saved = displayState();
        saved.policy.prefer_external = false;
        saved.status = "all-displays";
        saved.outputs[0].disabled = false;
        c.applyDisplayPolicy(saved);
        c.requestFinished(calls[1].id);
        compare(choice.value, "keep-on");
        compare(choice.currentIndex, 0);
        verify(!c.dirty && !c.trial, "docking saves independently of the layout preview");
        compare(c.displayPolicyError, "");
        verify(calls.every(call => call.method === "displayPolicy.set"));
    }
    function test_dockingPreferenceIsLockedDuringLayoutEdits() {
        const panel = makePanel();
        const c = panel.controller;
        c.selectOutput("eDP-1");
        c.openDetails();
        tryVerify(function () { return findChild(panel, "dockedLaptopBehavior") !== null; });
        const choice = findChild(panel, "dockedLaptopBehavior");
        c.edit("DP-1", "x", 1600);
        verify(!choice.interactive);
        verify(findChild(panel, "dockingSaveStatus").text.indexOf("Finish or discard") >= 0);
        choice.selected("keep-on");
        compare(calls.length, 0);
        c.reloadDraft();
        verify(choice.interactive);
        const state = displayState();
        state.layout.trial = {id: "trial", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(state);
        verify(!choice.interactive);
        choice.selected("keep-on");
        compare(calls.length, 0);
    }
    function test_draftSurvivesTelemetryAndUsesDaemonToken() {
        const panel = makePanel();
        const c = panel.controller;
        c.selectOutput("DP-1");
        c.edit("DP-1", "scale", 2);
        c.applyDisplayPolicy(displayState());
        compare(c.selectedDraft.scale, 2);
        verify(c.preview());
        compare(calls[0].method, "displayLayout.preview");
        compare(calls[0].params.outputs[1].scale, 2);
        verify(!("availableModes" in calls[0].params.outputs[1]));
        const value = displayState();
        value.layout.trial = { id: "token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        c.requestFinished(calls[0].id);
        verify(!c.canEdit);
        verify(waitForRendering(panel));
        tryCompare(findChild(panel, "revertDisplayLayout"), "activeFocus", true);
        compare(findChild(findChild(panel, "revertDisplayLayout"), "actionLabel").label, "Revert");
        compare(findChild(findChild(panel, "confirmDisplayLayout"), "actionLabel").label, "Keep");
        findChild(panel, "confirmDisplayLayout").clicked();
        compare(calls[1].method, "displayLayout.confirm");
        compare(calls[1].params.id, "token");
        value.layout.trial = null;
        c.applyDisplayPolicy(value);
        c.requestFinished(calls[1].id);
        verify(!c.dirty);
        compare(c.selectedDraft.scale, 1.5);
    }
    function test_topologyChangeBlocksStaleDraftAndReloads() {
        const c = makePanel().controller;
        c.edit("DP-1", "x", -200);
        const value = displayState();
        value.outputs.pop();
        c.applyDisplayPolicy(value);
        verify(c.stale && c.dirty);
        verify(!c.canPreview);
        compare(c.draft.length, 2, "preserve draft until explicit reload");
        c.reloadDraft();
        verify(!c.stale && !c.dirty);
        compare(c.draft.length, 1);
    }
    function test_reconnectionClearsOnlyResolvedCloseIntent() {
        const c = makePanel().controller;
        c.edit("DP-1", "x", 1800);
        verify(c.preview());
        c.deactivateUi();
        verify(c.revertOnArrival);
        c.transportFailed("lost preview response");
        verify(!c.canEdit);
        c.applyDisplayPolicy(displayState());
        verify(!c.revertOnArrival, "authoritative no-trial snapshot clears old close intent");
        c.reloadDraft();
        c.edit("DP-1", "x", 1800);
        verify(c.preview());
        const value = displayState();
        value.layout.trial = { id: "new-token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        const count = calls.length;
        c.requestFinished(calls[count - 1].id);
        compare(calls.length, count, "a later intentional preview is not auto-reverted");
    }
    function test_sameConnectorReplacementInvalidatesTrialAndExpiredCannotConfirm() {
        const c = makePanel().controller;
        c.edit("DP-1", "x", 1800);
        const value = displayState();
        value.layout.trial = { id: "token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        value.outputs[1].id = 99;
        c.applyDisplayPolicy(value);
        verify(c.stale);
        verify(!c.displayLayoutAction("confirm", { id: "token" }));
        c.stale = false;
        c.clock = Date.now() + 30000;
        verify(!c.displayLayoutAction("confirm", { id: "token" }));
        verify(c.displayLayoutAction("revert", { id: "token" }));
    }
    function test_trialTokensAndHiddenPreviewRevert() {
        const c = makePanel().controller;
        const value = displayState();
        value.layout.trial = { id: "opaque-token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        verify(!c.setPreferExternal(false));
        verify(!c.displayLayoutAction("confirm", { id: "stale-token" }));
        c.deactivateUi();
        compare(calls.length, 1);
        compare(calls[0].method, "displayLayout.revert");
        compare(calls[0].params.id, "opaque-token");
    }
    function test_closeWhilePreviewIsPending() {
        const c = makePanel().controller;
        c.edit("DP-1", "x", 1600);
        verify(c.preview());
        c.deactivateUi();
        const value = displayState();
        value.layout.trial = { id: "late-token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        compare(calls.length, 1, "wait for preview acknowledgement before sending revert");
        c.requestFinished(calls[0].id);
        compare(calls.length, 2);
        compare(calls[1].method, "displayLayout.revert");
        compare(calls[1].params.id, "late-token");
    }
}
