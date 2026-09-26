pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Displays as Displays

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
            Displays.DisplayController { id: controller }
            Displays.DisplayContent { id: content; controller: panel.controller }
        }
    }
    function displayState() {
        return { available: true, policy: { prefer_external: true }, status: "external", layout: { saved: { outputs: [] }, trial: null },
            outputs: [{ name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: true, availableModes: ["1920x1200@60.00Hz"] },
                { name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, availableModes: ["3840x2160@60.00Hz"] }] };
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applyDisplayPolicy(displayState());
        verify(waitForRendering(panel));
        calls = [];
        return panel;
    }
    function test_groupedSettingsRemainDraftOnly() {
        const panel = makePanel();
        const c = panel.controller;
        c.openDetails();
        // The details Loader is asynchronous: an early child can exist before
        // the inspector's Repeater delegates have finished being created.
        tryVerify(function () { return panel.detailsItem !== null; });
        verify(findChild(panel, "displayModeCard") !== null);
        findChild(panel, "displayScale").selected("2");
        findChild(panel, "displayRotation").selected("1");
        findChild(panel, "displayX").edited("-200");
        compare(c.selectedDraft.scale, 2);
        compare(c.selectedDraft.transform, 1);
        compare(c.selectedDraft.x, -200);
        compare(c.selectedOutput.scale, 1.5);
        verify(c.dirty);
        findChild(panel, "displayPositionReference").selected("eDP-1");
        findChild(panel, "displayPlace-left").clicked();
        verify(c.selectedDraft.x < 0);
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
    function test_settingsInformationAndTextNavigation() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        const state = displayState();
        state.outputs[1].make = "Dell";
        state.outputs[1].model = "U2723QE";
        state.outputs[1].serial = "TEST-123";
        c.applyDisplayPolicy(state);
        c.openDetails();
        tryVerify(function () { return findChild(panel, "displayDetailsTabs") !== null; });
        const tabs = findChild(panel, "displayDetailsTabs");
        const info = findChild(panel, "displayInformation");
        compare(tabs.tabs.length, 2);
        compare(tabs.selectedValue, "settings");
        const x = findChild(panel, "displayX");
        x.focusInput(false);
        x.cursorPosition = 2;
        const before = c.selectedDraft.x;
        keyClick(Qt.Key_Left);
        compare(x.cursorPosition, 1);
        verify(c.detailsOpen, "Left edits text rather than closing details");
        compare(c.selectedDraft.x, before);
        c.edit("DP-1", "scale", 2);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(c.detailsTab, "information");
        verify(info.visible);
        compare(info.entries.find(e => e.label === "Scale").value, "150%", "Information shows observed state, not the draft");
        compare(info.entries.find(e => e.label === "Manufacturer").value, "Dell");
        verify(!findChild(panel, "displayLayoutWorkspace").visible);
        verify(c.triggerDetailAction("arrange"));
        compare(c.detailsTab, "settings");
        compare(c.selectedDraft.scale, 2);
        c.selectOutput("eDP-1");
        c.cycleDetailsTab();
        verify(!info.entries.some(e => e.label === "Serial number"), "missing metadata is omitted");
        compare(c.detailActions.filter(a => a.visible && a.presentation.group === "toolbar").length, 2);
        compare(calls.length, 0);
    }
    function test_sharedSelectionSearchAndDraftRetention() {
        const c = makePanel().controller;
        compare(c.filteredResults.length, 2);
        compare(c.selectedName, "DP-1", "enabled displays sort first");
        c.edit("DP-1", "scale", 2);
        c.moveSelection(1);
        compare(c.selectedName, "eDP-1");
        verify(!c.navigationBlocked, "a draft does not prevent browsing displays");
        c.openDetails();
        verify(c.detailsOpen);
        c.cycleDetailsTab();
        compare(c.detailsTab, "information");
        c.selectOutput("DP-1");
        compare(c.selectedDraft.scale, 2);
        c.applyDisplayPolicy(displayState());
        compare(c.selectedName, "DP-1");
        compare(c.selectedDraft.scale, 2);
        const store = c.selectionModel;
        store.rankRequestsEnabled = false;
        c.filterText = "Laptop";
        store.applyRustRanking(store.searchOwner, store.searchGeneration, ["displays::eDP-1"]);
        compare(c.filteredResults.length, 1);
        compare(c.selectedName, "eDP-1");
        c.filterText = "not a display";
        store.applyRustRanking(store.searchOwner, store.searchGeneration, []);
        verify(!c.hasSelection);
        verify(c.dirty, "zero search results must not discard the layout");
        c.filterText = "";
        c.selectOutput("DP-1");
        compare(c.selectedDraft.scale, 2);
        verify(c.triggerDetailAction("toggle-enabled"));
        compare(calls.length, 0);
    }
    function test_providerResultsAndLiveActions() {
        const c = makePanel().controller;
        const provider = c.displayProvider;
        const results = provider.resultsForOutputs(c.outputs);
        compare(results.length, 2);
        compare(results[0].key, "displays::eDP-1");
        verify(results[0].subtitle.indexOf("Off · External display preferred") >= 0);
        verify(results[1].keywords.indexOf("DP-1") >= 0);
        const internalActions = provider.actionsFor(results[0]);
        verify(!internalActions.find(a => a.id === "toggle-enabled").visible);
        verify(!internalActions.find(a => a.id === "identify").enabled);
        verify(!provider.actionsFor(results[1]).find(a => a.id === "preview").enabled);
        verify(provider.execute({ result: results[1], actionId: "toggle-enabled" }));
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
    function test_listSummaryAndWorkspaceKeyboard() {
        const panel = makePanel();
        const c = panel.controller;
        compare(c.activeCount, 1, "summary shows actual state, not the fallback preview draft");
        verify(c.draft[0].enabled, "preview retains laptop fallback");
        verify(findChild(panel, "displayList") !== null);
        verify(!findChild(panel, "chooserPowerToggle").visible);
        compare(findChild(panel, "displayList").searchActionIcon, "", "no separate settings gear");
        compare(findChild(panel, "displayList").listOptionsComponent, null);
        c.uiActive = true;
        c.selectOutput("DP-1");
        c.openDetails();
        verify(waitForRendering(panel));
        tryVerify(function () { return findChild(panel, "displayWorkspaceCanvas") !== null; });
        const canvas = findChild(panel, "displayWorkspaceCanvas");
        verify(canvas !== null);
        verify(!canvas.visible, "the canvas is not the initial details view");
        verify(c.triggerDetailAction("arrange"));
        tryVerify(function () { return canvas.visible; });
        canvas.forceActiveFocus();
        calls = [];
        const before = c.selectedDraft.x;
        keyClick(Qt.Key_Right);
        compare(c.selectedDraft.x, before + 16);
        keyClick(Qt.Key_Left, Qt.ShiftModifier);
        compare(c.selectedDraft.x, before + 15);
        compare(calls.length, 0, "moving is draft-only");
        verify(c.canPreview);
        verify(!c.canSetPolicy);
        keyClick(Qt.Key_Tab);
        verify(!canvas.activeFocus, "Tab exits the spatial composite");
        c.closeDetails();
        verify(c.discardPrompt);
        c.dismissNavigation();
        verify(c.detailsOpen && !c.discardPrompt);
        c.discardAndClose();
        verify(!c.dirty && !c.detailsOpen);
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
    function test_narrowWorkspaceRevealsFocusedControls() {
        const panel = makePanel();
        panel.width = 390;
        panel.height = 600;
        const c = panel.controller;
        c.uiActive = true;
        c.selectOutput("DP-1");
        c.openDetails();
        tryVerify(function () { return panel.detailsItem !== null; });
        verify(c.triggerDetailAction("arrange"));
        const page = findChild(panel, "displayLayoutWorkspace");
        const fieldY = findChild(panel, "displayY");
        const canvas = findChild(panel, "displayWorkspaceCanvas");
        // Arrange queues canvas focus; let it finish before focusing the field,
        // and settle the stacked layout before checking focus-driven scrolling.
        tryCompare(canvas, "activeFocus", true);
        verify(waitForPolish(panel.Window.window));
        fieldY.focusInput(false);
        tryCompare(fieldY, "inputActiveFocus", true);
        tryVerify(function () { return page.contentY > 0; });
        const position = fieldY.mapToItem(page, 0, 0);
        verify(position.y >= 0);
        verify(position.y + fieldY.height <= page.height + 1);
        for (const name of ["displayResolution", "displayRefreshRate", "displayScale", "displayRotation", "displayX", "displayY"]) {
            const field = findChild(panel, name);
            verify(field.mapToItem(panel, field.width, 0).x <= panel.width);
            verify(field.Accessible.name.length > 0);
        }
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
