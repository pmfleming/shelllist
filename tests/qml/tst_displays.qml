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
            readonly property Ui.DetailsNavigation navigation: content.detailsNavigation
            readonly property Ui.ChooserListPane list: content.listItem
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
            outputs: [{ id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: true, supported: true, internal: true, mirror_of: "", current_mode: "1920x1200@60.00Hz", modes: [{id: "1920x1200@60.00Hz", width: 1920, height: 1200, rate: 60, size: "1920x1200"}] },
                { id: 1, name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, supported: true, internal: false, mirror_of: "", current_mode: "3840x2160@60.00Hz", modes: [{id: "3840x2160@60.00Hz", width: 3840, height: 2160, rate: 60, size: "3840x2160"}] }] };
    }
    function test_normalizedModesRemainLocalUntilPreview() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        const state = displayState();
        // Opaque IDs deliberately cannot be parsed as compositor mode strings.
        state.outputs[1].current_mode = "observed-mode";
        state.outputs[1].modes = [
            {id: "observed-mode", width: 3840, height: 2160, rate: 59.94, size: "3840x2160"},
            {id: "alternate-mode", width: 2560, height: 1440, rate: 120, size: "2560x1440"}
        ];
        c.applyDisplayPolicy(state);
        c.selectOutput("DP-1");
        c.openDetails();
        waitForDetails(panel);
        const resolution = findChild(panel, "displayResolution");
        compare(resolution.options.length, 2);
        panel.navigation.focusContent();
        tryVerify(() => panel.navigation.browsing);
        for (let i = 0; i < panel.navigation.targets.length && panel.navigation.currentTarget !== resolution; ++i)
            keyClick(Qt.Key_Tab);
        compare(panel.navigation.currentTarget, resolution);
        keyClick(Qt.Key_Return);
        tryVerify(() => resolution.activeFocus && resolution.editSession.active);
        keyClick(Qt.Key_Space);
        tryCompare(resolution.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        compare(c.selectedDraft.mode, "observed-mode", "Escape discards field-local choice");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        tryCompare(resolution.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(c.selectedDraft.mode, "alternate-mode");
        compare(c.validationError, "");
        compare(calls.length, 0, "saving a field changes only the layout draft");
        compare(c.selectedOutput.current_mode, "observed-mode");
        verify(c.preview());
        compare(calls[0].params.outputs[1].mode, "alternate-mode");
        verify(!("modes" in calls[0].params.outputs[1]));
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
    function arrangementPanel(withThird) {
        const panel = makePanel();
        const state = displayState();
        state.outputs[0].disabled = false;
        if (withThird)
            state.outputs.push(Object.assign({}, state.outputs[1], { id: 2, name: "HDMI-A-1", x: 4096 }));
        panel.controller.applyDisplayPolicy(state);
        panel.controller.uiActive = true;
        panel.controller.selectOutput("DP-1");
        panel.controller.openDetails();
        waitForDetails(panel);
        return panel;
    }
    function placementCases() {
        return [
            {tag: "left", side: "left", key: Qt.Key_L, x: -2560, y: 0},
            {tag: "above", side: "above", key: Qt.Key_U, x: 0, y: -1440}
        ];
    }
    function test_directionButtonsAndKeyboard_data() { return [placementCases()[0]]; }
    function test_directionButtonsAndKeyboard(data) {
        const panel = arrangementPanel(false);
        const c = panel.controller;
        const map = findChild(panel, "displayArrangementSummary");
        const controls = findChild(panel, "displayArrangementControls");
        const button = findChild(panel, "displayPlace-" + data.side);
        verify(button.visible && button.enabled);
        verify(controls.mapToItem(panel.detailsItem, 0, 0).y >= map.mapToItem(panel.detailsItem, 0, map.height).y);
        compare(findChild(panel, "displayX"), null);
        compare(findChild(panel, "displayY"), null);
        verify(!findChild(panel, "displayPositionReference").visible, "two monitors have an automatic reference");
        mouseClick(button);
        compare(c.selectedDraft.x, data.x);
        compare(c.selectedDraft.y, data.y);
        c.reloadDraft();
        panel.list.focusSearch();
        keyClick(data.key, Qt.AltModifier);
        compare(c.selectedDraft.x, data.x);
        compare(c.selectedDraft.y, data.y);
        const saved = JSON.stringify(c.draft);
        keyClick(data.key, Qt.AltModifier);
        compare(JSON.stringify(c.draft), saved, "repeating the current direction is a no-op");
        c.detailsTab = "information";
        verify(button.visible && controls.visible);
        panel.navigation.focusContent();
        verify(panel.navigation.targets.every(item => !item.objectName.startsWith("displayPlace-")));
        compare(calls.length, 0, "buttons and Alt commands are draft-only");
    }
    function beginMapDrag(panel) {
        const map = findChild(panel, "displayArrangementSummary");
        const pointer = findChild(map, "displayMapPointer-DP-1");
        const start = pointer.mapToItem(map, pointer.width / 2, pointer.height / 2);
        mousePress(pointer, pointer.width / 2, pointer.height / 2);
        verify(!map.dragging, "a click must not start a drag");
        mouseMove(map, start.x + 12, start.y);
        verify(map.dragging && panel.controller.layoutDragging);
        verify(pointer.enabled, "dragging cannot disable its own pointer grab");
        return map;
    }
    function dragToEdge(map, side) {
        const reference = findChild(map, "displayMapScreen-eDP-1");
        const x = reference.x + (side === "left" ? 2 : side === "right" ? reference.width - 2 : reference.width / 2);
        const y = reference.y + (side === "above" ? 2 : side === "below" ? reference.height - 2 : reference.height / 2);
        mouseMove(map, x, y);
        compare(map.targetEdge.reference, "eDP-1");
        compare(map.targetEdge.side, side);
        return { x: x, y: y };
    }
    function test_dragAndButtonsUseIdenticalPlacement_data() { return [placementCases()[1]]; }
    function test_dragAndButtonsUseIdenticalPlacement(data) {
        const panel = arrangementPanel(false);
        const c = panel.controller;
        const original = JSON.stringify(c.draft);
        const map = beginMapDrag(panel);
        const factor = map.factor;
        const drop = dragToEdge(map, data.side);
        verify(findChild(map, "displayDropGhost").visible);
        compare(map.candidate.error, "");
        compare(map.factor, factor, "fitting stays frozen while choosing an edge");
        compare(JSON.stringify(c.draft), original, "hover never edits the draft");
        verify(!c.canPreview && !c.placeSelected("above"), "actions cannot mutate during a drag");
        mouseRelease(map, drop.x, drop.y, Qt.LeftButton, Qt.AltModifier);
        verify(!map.dragging && !c.layoutDragging && !map.activeFocus);
        compare(c.selectedDraft.x, data.x);
        compare(c.selectedDraft.y, data.y);
        compare(c.referenceName, "eDP-1");
        compare(calls.length, 0, "Alt cannot bypass relative placement or submit the draft");
    }
    function test_cancelledDragDoesNotCommit_data() {
        return ["escape", "unplug"].map(value => ({tag: value, route: value}));
    }
    function test_cancelledDragDoesNotCommit(data) {
        const panel = arrangementPanel(false);
        const c = panel.controller;
        // An existing edit must survive cancellation/topology changes.
        c.edit("DP-1", "scale", 2);
        const original = JSON.stringify(c.draft);
        const map = beginMapDrag(panel);
        const drop = dragToEdge(map, "above");
        if (data.route === "escape") keyClick(Qt.Key_Escape);
        else {
            const state = displayState();
            state.outputs[0].disabled = false;
            state.outputs.pop();
            c.applyDisplayPolicy(state);
        }
        mouseRelease(map, drop.x, drop.y);
        verify(!map.dragging && !c.layoutDragging);
        compare(JSON.stringify(c.draft), original);
        verify(!findChild(map, "displayDropGhost").visible);
        compare(calls.length, 0);
    }
    function test_referenceFieldAndPlacementSafety() {
        const panel = arrangementPanel(true);
        const c = panel.controller;
        const reference = findChild(panel, "displayPositionReference");
        verify(reference.visible && reference.interactive);
        compare(c.referenceName, "eDP-1");
        const original = JSON.stringify(c.draft);
        panel.navigation.focusContent();
        panel.navigation.currentTarget = reference;
        keyClick(Qt.Key_Return);
        tryVerify(() => reference.editSession.active);
        keyClick(Qt.Key_Space);
        tryCompare(reference.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        compare(c.referenceName, "eDP-1");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(c.referenceName, "HDMI-A-1");
        compare(JSON.stringify(c.draft), original, "reference selection is presentation-only");
        c.referenceName = "eDP-1";
        c.edit("HDMI-A-1", "x", -2560);
        verify(!findChild(panel, "displayPlace-left").enabled);
        verify(findChild(panel, "displayArrangementHint").text.includes("Would overlap HDMI-A-1"));
        const collisionDraft = JSON.stringify(c.draft);
        verify(!c.placeSelected("left"));
        const map = beginMapDrag(panel);
        const drop = dragToEdge(map, "left");
        verify(map.candidate.error.includes("Would overlap"));
        mouseRelease(map, drop.x, drop.y);
        compare(JSON.stringify(c.draft), collisionDraft, "an invalid drag cannot commit");
        c.edit("HDMI-A-1", "enabled", false);
        compare(c.placementReferences.length, 1);
        verify(!reference.visible);
        verify(c.placeSelected("left"), "disabled parked displays do not obstruct placement");
        c.stale = true;
        verify(!c.placeSelected("above"));
        c.stale = false;
        c.discardPrompt = true;
        verify(!c.placeSelected("above"));
        c.discardPrompt = false;
        c.actionInFlight = true;
        verify(!c.placeSelected("above"));
        c.actionInFlight = false;
        c.selectOutput("HDMI-A-1");
        verify(!c.canArrange && !c.placeSelected("above"));
        verify(findChild(panel, "displayArrangementHint").text.includes("Enable"));
        compare(calls.length, 0);
    }
    function test_dragRetainsTelemetryButCancelsGeometryChanges() {
        const panel = arrangementPanel(true);
        const c = panel.controller;
        const map = beginMapDrag(panel);
        dragToEdge(map, "above");
        const state = displayState();
        state.outputs[0].disabled = false;
        state.outputs.push(Object.assign({}, state.outputs[1], { id: 2, name: "HDMI-A-1", x: 4096 }));
        state.outputs[1].focused = true;
        c.applyDisplayPolicy(state);
        verify(map.dragging, "ordinary telemetry must not interrupt a drag");
        c.edit("DP-1", "scale", 2);
        verify(!map.dragging, "a concurrent geometry edit cancels the old candidate");
        mouseRelease(map);
        compare(c.selectedDraft.x, 1536);
        compare(c.selectedDraft.scale, 2);
        compare(calls.length, 0);
    }
    function test_modeChangesRevalidatePlacementBeforePreview() {
        const panel = arrangementPanel(false);
        const c = panel.controller;
        verify(c.placeSelected("left"));
        verify(c.canPreview);
        c.edit("DP-1", "scale", 1);
        verify(!c.canPreview && c.validationError.includes("overlaps"));
        verify(!c.preview());
        verify(c.placeSelected("left"));
        compare(c.selectedDraft.x, -3840);
        verify(c.canPreview);
        c.dismissNavigation();
        verify(c.discardPrompt, "leaving a dirty layout still requires explicit discard");
        compare(calls.length, 0);
    }
    function test_focusSettingsAreGlobalAcknowledgedAndRetryable() {
        const panel = makePanel();
        const c = panel.controller;
        c.applyDisplayPolicy(focusState());
        c.openGlobalSettings();
        compare(c.detailsTab, "focus");
        waitForDetails(panel);
        const choice = findChild(panel, "focusSetting-misc:mouse_move_focuses_monitor");
        verify(choice !== null && choice.interactive);
        verify(choice instanceof Ui.ToggleRow);
        compare(choice.checked, true);
        choice.clicked();
        compare(calls.length, 1);
        compare(calls[0].method, "displayFocus.set");
        compare(calls[0].params.values["misc:mouse_move_focuses_monitor"], false);
        compare(Object.keys(calls[0].params.values).length, 1, "only the chosen setting is overridden");
        compare(choice.checked, true, "no optimistic setting change");
        verify(!choice.interactive);
        c.requestFailed(calls[0].id, "compositor refused focus settings");
        verify(choice.interactive);
        compare(choice.checked, true);
        choice.clicked();
        const saved = focusState();
        saved.focus.values["misc:mouse_move_focuses_monitor"] = false;
        saved.focus.saved["misc:mouse_move_focuses_monitor"] = false;
        c.applyDisplayPolicy(saved);
        c.requestFinished(calls[1].id);
        compare(choice.checked, false);
        verify(!c.dirty, "focus settings are not layout drafts");
        c.selectOutput("eDP-1");
        compare(choice.checked, false, "changing selection does not change global focus settings");
        const unsupported = findChild(panel, "focusSetting-input:focus_on_close");
        verify(!unsupported.interactive);
        verify(!c.setFocusSetting("input:focus_on_close", 1));
        c.selectFocusPage("focus-diagnostics");
        const reset = findChild(panel, "resetDisplayFocus");
        verify(reset.enabled);
        reset.clicked();
        compare(calls[2].method, "displayFocus.reset");
        c.applyDisplayPolicy(focusState());
        c.requestFinished(calls[2].id);
        compare(choice.checked, true);
        verify(!reset.enabled);
        c.openDetails();
        c.cycleDetailsTab();
        compare(c.detailsTab, "information");
        c.cycleDetailsTab();
        compare(c.detailsTab, "settings");
    }
    function test_focusControlsRespectLayoutTrialsDisconnectsAndNumericValidation() {
        const panel = makePanel();
        const c = panel.controller;
        c.applyDisplayPolicy(focusState());
        c.openGlobalSettings();
        waitForDetails(panel);
        c.selectFocusPage("focus-pointer");
        const number = findChild(panel, "focusNumber-input:follow_mouse_threshold");
        number.edited("");
        verify(!number.inputValid);
        number.editingFinished();
        compare(calls.length, 0);
        number.edited("-1");
        verify(!number.inputValid);
        number.edited("2.5");
        verify(number.inputValid);
        number.editingFinished();
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
        verify(!c.canArrange);
        verify(findChild(panel, "displayArrangementHint").text.includes("Mirrors"));
        compare(findChild(panel, "displayPositionCard"), null);
        const oldX = c.selectedDraft.x;
        c.edit("DP-1", "x", 9999);
        verify(!c.placeSelected("left"));
        compare(c.selectedDraft.x, oldX, "mirrors cannot be positioned independently");
        compare(findChild(panel, "displayArrangementSummary").values.length, 2, "mirrors remain visible as physical screens");
        verify(!findChild(panel, "displayMapScreen-DP-1").movable, "mirrors cannot be dragged independently");
        compare(calls.length, 0);
        content.selected("");
        compare(c.selectedDraft.mirror_of, "");
        verify(c.canArrange);
        verify(c.selectedDraft.x >= 1536, "extended content gets an independent position");
        content.selected("eDP-1");
        verify(c.preview());
        compare(calls[0].method, "displayLayout.preview");
        compare(calls[0].params.outputs[1].mirror_of, "eDP-1");
        compare(calls[0].params.outputs[0].mirror_of, "");
        const observed = displayState();
        observed.outputs[0].disabled = false;
        observed.outputs[1].mirror_of = "eDP-1";
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
        state.outputs[1].mirror_of = "eDP-1";
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
    function test_dockingChoiceWaitsForAcknowledgementAndCanRetry() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const choice = findChild(panel, "dockedLaptopBehavior");
        const status = findChild(panel, "dockingSaveStatus");
        panel.navigation.focusContent();
        panel.navigation.currentTarget = choice;
        keyClick(Qt.Key_Return);
        tryVerify(() => choice.editSession.active);
        keyClick(Qt.Key_Up); // Native arrows change only the local draft.
        compare(calls.length, 0);
        keyClick(Qt.Key_Return);
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
        panel.navigation.currentTarget = choice;
        keyClick(Qt.Key_Return);
        tryVerify(() => choice.editSession.active);
        keyClick(Qt.Key_Up);
        compare(calls.length, 1);
        keyClick(Qt.Key_Return);
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
        const count = calls.length;
        c.edit("DP-1", "x", 1600);
        verify(!choice.interactive);
        choice.selected("auto-off");
        compare(calls.length, count, "a layout draft prevents a concurrent docking write");
        c.reloadDraft();
        saved.layout.trial = {id: "trial", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(saved);
        verify(!choice.interactive);
        choice.selected("auto-off");
        compare(calls.length, count, "a layout trial also prevents docking writes");
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
        verify(!("modes" in calls[0].params.outputs[1]));
        verify(!("internal" in calls[0].params.outputs[1]));
        const pending = displayState();
        pending.policy.prefer_external = false;
        pending.outputs[1].x = 1600;
        c.applyDisplayPolicy(pending);
        verify(!c.stale, "unacknowledged preview changes do not invalidate its draft");
        compare(c.selectedDraft.scale, 2);
        const value = displayState();
        value.layout.trial = { id: "token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        c.requestFinished(calls[0].id);
        verify(!c.canEdit);
        verify(waitForRendering(panel));
        const revert = findChild(panel, "detailAction:revert");
        const confirm = findChild(panel, "detailAction:confirm");
        tryCompare(revert, "activeFocus", true);
        compare(revert.Accessible.name, "Revert layout");
        compare(confirm.Accessible.name, "Keep layout");
        compare(findChild(revert, "actionLabel").label, "");
        compare(findChild(confirm, "actionLabel").label, "");
        verify(!c.displayLayoutAction("confirm", {id: "stale-token"}));
        keyClick(Qt.Key_Tab);
        tryCompare(confirm, "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(calls[1].method, "displayLayout.confirm");
        compare(calls[1].params.id, "token");
        value.layout.trial = null;
        c.applyDisplayPolicy(value);
        c.requestFinished(calls[1].id);
        verify(!c.dirty);
        compare(c.selectedDraft.scale, 1.5);
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
        c.deactivateUi();
        compare(calls[calls.length - 1].method, "displayLayout.revert");
        compare(calls[calls.length - 1].params.id, "new-token");
    }
    function test_sameConnectorReplacementInvalidatesTrialAndExpiredCannotConfirm() {
        const panel = makePanel();
        const c = panel.controller;
        c.openDetails();
        waitForDetails(panel);
        c.edit("DP-1", "x", 1800);
        const value = displayState();
        value.layout.trial = { id: "token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        const oldResult = c.displayProvider.resultsFor(c.outputs).find(result => result.id === "DP-1");
        const replacement = JSON.parse(JSON.stringify(value));
        replacement.outputs[1].id = 99;
        c.applyDisplayPolicy(replacement);
        verify(c.stale);
        compare(c.displayProvider.actionsFor(oldResult).length, 0, "stale physical identity exposes no actions");
        verify(!c.displayProvider.execute({result: oldResult, actionId: "toggle-enabled"}));
        verify(!c.displayLayoutAction("confirm", { id: "token" }));
        c.stale = false;
        c.clock = Date.now() + 30000;
        verify(!c.displayLayoutAction("confirm", { id: "token" }));
        verify(c.displayLayoutAction("revert", { id: "token" }));
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
