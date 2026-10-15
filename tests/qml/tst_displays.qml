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
        return { available: true, baseline: "opaque-native-baseline", policy: { prefer_external: true }, status: "external", layout: { saved: { outputs: [] }, trial: null },
            outputs: [{ id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: true, supported: true, internal: true, mirror_of: "", current_mode: "1920x1200@60.00Hz", modes: [{id: "1920x1200@60.00Hz", width: 1920, height: 1200, rate: 60, size: "1920x1200"}] },
                { id: 1, name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, supported: true, internal: false, mirror_of: "", current_mode: "3840x2160@60.00Hz", modes: [{id: "3840x2160@60.00Hz", width: 3840, height: 2160, rate: 60, size: "3840x2160"}] }] };
    }
    function test_unavailablePolicyPointsToDaemonOwner() {
        const panel = makePanel();
        panel.controller.applyDisplayPolicy({available: false});
        verify(panel.controller.statusMessage.includes("services.bar-daemon.displays.enable"));
        verify(!panel.controller.canPreview);
        compare(calls.length, 0);
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
    function test_enableDisableCommandsPreviewAndAcknowledge_data() {
        return [
            {tag: "revert-disable", index: 1, wasEnabled: true, keyboard: true, keep: false}
        ];
    }
    function test_enableDisableCommandsPreviewAndAcknowledge(data) {
        const panel = makePanel();
        const c = panel.controller;
        const initial = displayState();
        initial.outputs[0].disabled = false;
        initial.outputs[1].disabled = false;
        initial.outputs[data.index].disabled = !data.wasEnabled;
        c.applyDisplayPolicy(initial);
        c.uiActive = true;
        const name = initial.outputs[data.index].name;
        c.selectOutput(name);
        c.openDetails();
        waitForDetails(panel);
        // Action descriptors rebuild their delegates when selection/drafts change.
        const power = () => findChild(panel, "detailAction:toggle-enabled");
        verify(power().visible && power().enabled);
        compare(power().Accessible.name, data.wasEnabled ? "Disable" : "Enable");
        if (data.keyboard) {
            panel.list.focusSearch();
            keyClick(Qt.Key_E, Qt.AltModifier);
        } else {
            mouseClick(power());
        }
        compare(c.selectedDraft.enabled, !data.wasEnabled);
        tryVerify(() => power()?.Accessible.name === (data.wasEnabled ? "Enable" : "Disable"));
        compare(c.selectedOutput.disabled, !data.wasEnabled, "toggle changes only the draft before Preview");
        compare(calls.length, 0);
        const preview = findChild(panel, "detailAction:preview");
        verify(preview.enabled);
        mouseClick(preview);
        compare(calls.length, 1);
        compare(calls[0].method, "displayLayout.preview");
        compare(calls[0].params.outputs.find(output => output.name === name).enabled, !data.wasEnabled);
        tryVerify(() => power() && !power().enabled, 1000, "no second toggle during an unacknowledged preview");
        const trial = JSON.parse(JSON.stringify(initial));
        trial.outputs[data.index].disabled = data.wasEnabled;
        trial.layout.trial = {id: "enablement-trial", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(trial);
        c.requestFinished(calls[0].id);
        const dialog = findChild(panel, "displayTrialDialog");
        tryVerify(() => dialog.visible);
        verify(!power().enabled);
        const action = data.keep ? "confirm" : "revert";
        mouseClick(findChild(dialog, "detailAction:" + action));
        compare(calls.length, 2);
        compare(calls[1].method, "displayLayout." + action);
        compare(calls[1].params.id, "enablement-trial");
        const acknowledged = JSON.parse(JSON.stringify(data.keep ? trial : initial));
        acknowledged.layout.trial = null;
        acknowledged.layout.manual_enablement = data.keep;
        c.applyDisplayPolicy(acknowledged);
        c.requestFinished(calls[1].id);
        const enabled = data.keep ? !data.wasEnabled : data.wasEnabled;
        compare(c.selectedDraft.enabled, enabled);
        compare(c.selectedOutput.disabled, !enabled);
        tryVerify(() => power()?.Accessible.name === (enabled ? "Disable" : "Enable"));
        verify(!c.dirty && !c.trial);
        verify(!dialog.visible);
    }
    function test_lastActiveDisplayCannotBeDisabledThroughUi() {
        const panel = makePanel();
        const c = panel.controller;
        const state = displayState();
        // Disabled outputs can report (0, 0), overlapping the active monitor.
        state.outputs[1].x = 0;
        c.applyDisplayPolicy(state);
        c.uiActive = true;
        c.selectOutput("DP-1");
        c.openDetails();
        waitForDetails(panel);
        const power = () => findChild(panel, "detailAction:toggle-enabled");
        verify(power().visible && !power().enabled, "the only enabled screen has no Disable command");
        mouseClick(power());
        panel.list.focusSearch();
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(c.selectedDraft.enabled && !c.dirty);
        compare(calls.length, 0);
        // An explicit replacement can be staged first, then the old screen disabled.
        c.selectOutput("eDP-1");
        tryVerify(() => power()?.enabled);
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(c.selectedDraft.enabled);
        verify(!c.canPreview && c.validationError.includes("overlaps"));
        keyClick(Qt.Key_R, Qt.AltModifier);
        verify(c.canPreview, "placing the enabled laptop beside the external display clears the overlap");
        verify(c.selectedDraft.x > 0);
        c.selectOutput("DP-1");
        tryVerify(() => power()?.enabled);
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(!c.selectedDraft.enabled && c.canPreview);
        compare(calls.length, 0, "the swap still needs a single guarded Preview");
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
    function test_cancelledDragDoesNotCommit_data() {
        return [{tag: "escape", route: "escape"}];
    }
    function test_cancelledDragDoesNotCommit(data) {
        const panel = arrangementPanel(false);
        const c = panel.controller;
        // An existing edit must survive cancellation/topology changes.
        c.edit("DP-1", "scale", 2);
        const original = JSON.stringify(c.draft);
        const map = beginMapDrag(panel);
        const drop = dragToEdge(map, "above");
        keyClick(Qt.Key_Escape);
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
        const feedback = findChild(panel.list, "feedbackText").parent;
        tryVerify(() => feedback.fullText.includes("Would overlap HDMI-A-1"));
        compare(feedback.messageTone, "warning");
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
        // Keep safety gates in the acknowledged focus-policy workflow, without
        // another numeric-field/viewport geometry fixture.
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
        const feedback = findChild(panel.list, "feedbackText").parent;
        tryVerify(() => feedback.fullText.includes("black bars may appear"));
        compare(feedback.contributions.filter(entry => entry.text.includes("Mirrors")).length, 1);
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
    function test_dockingManualStateCanReturnToTheAlreadySavedPreference() {
        const panel = makePanel();
        const c = panel.controller;
        const state = displayState();
        state.policy.prefer_external = false;
        state.layout.manual_enablement = true;
        c.applyDisplayPolicy(JSON.parse(JSON.stringify(state)));
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const choice = findChild(panel, "dockedLaptopBehavior");
        compare(choice.value, "manual");
        verify(choice.contentItem.text.includes("off"), "the saved preference must not masquerade as the effective mode");
        verify(!choice.options[choice.currentIndex].enabled, "manual layout is an observed state, not an invented policy command");
        for (const save of [false, true, true]) {
            mouseClick(choice);
            tryCompare(choice.popup, "visible", true);
            mouseClick(findChild(choice.popup.contentItem, "dropDownOption-" + choice.optionIndex("keep-on")));
            compare(choice.editSession.displayedValue, "keep-on");
            const before = calls.length;
            keyClick(save ? Qt.Key_Return : Qt.Key_Escape);
            compare(calls.length, before + (save ? 1 : 0));
            compare(choice.value, "manual", "no optimistic removal of the manual override");
            if (save) {
                compare(calls[before].params.prefer_external, false, "an explicit choice can resume the same stored preference");
                c.requestFailed(calls[before].id, "Policy save failed");
            }
        }
        mouseClick(choice);
        tryCompare(choice.popup, "visible", true);
        mouseClick(findChild(choice.popup.contentItem, "dropDownOption-" + choice.optionIndex("keep-on")));
        keyClick(Qt.Key_Return);
        state.layout.manual_enablement = false;
        state.status = "pending";
        c.applyDisplayPolicy(JSON.parse(JSON.stringify(state)));
        c.requestFinished(calls[calls.length - 1].id);
        compare(choice.value, "keep-on");
        verify(c.selectedOutput.disabled, "policy acknowledgement is not evidence that hardware has changed");
        state.outputs[0].disabled = false;
        state.status = "all-displays";
        c.applyDisplayPolicy(JSON.parse(JSON.stringify(state)));
        verify(!c.selectedOutput.disabled);
        compare(choice.value, "keep-on");
    }
    function test_dockingRemainsEditableWithoutLayoutBaseline() {
        const panel = makePanel();
        const c = panel.controller;
        const state = displayState();
        state.baseline = "";
        c.applyDisplayPolicy(state);
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const choice = findChild(panel, "dockedLaptopBehavior");
        verify(!findChild(panel, "displayScale").enabled, "layout edits still require a baseline");
        verify(choice.enabled && choice.interactive, "docking policy has its own availability guard");
        mouseClick(choice);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Escape);
        compare(calls.length, 0);
    }
    function test_policyPendingDoesNotInventLayoutValues() {
        const panel = makePanel();
        const c = panel.controller;
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const scale = findChild(panel, "displayScale");
        const resolution = findChild(panel, "displayResolution");
        compare(scale.value, "1.25");
        verify(c.setPreferExternal(false));
        const state = displayState();
        state.policy.prefer_external = false;
        c.applyDisplayPolicy(state);
        compare(scale.value, "1.25", "pending acknowledgement must not fall back to a fabricated 100% scale");
        compare(resolution.value, "1920x1200");
        c.requestFinished(calls[0].id);
        compare(scale.value, "1.25");
    }
    function test_dockingWaitsForHardwareBeforeAcceptingOnOff_data() {
        return [{tag: "keep-on", preferExternal: false}];
    }
    function test_dockingWaitsForHardwareBeforeAcceptingOnOff(data) {
        const panel = makePanel();
        const c = panel.controller;
        const initial = displayState();
        initial.policy.prefer_external = !data.preferExternal;
        initial.outputs[0].disabled = !data.preferExternal;
        initial.docking_state = "settled";
        c.applyDisplayPolicy(initial);
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const choice = findChild(panel, "dockedLaptopBehavior");
        panel.navigation.focusContent();
        panel.navigation.currentTarget = choice;
        keyClick(Qt.Key_Return);
        tryVerify(() => choice.editSession.active);
        keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        const option = data.preferExternal ? "auto-off" : "keep-on";
        mouseClick(findChild(choice.popup.contentItem, "dropDownOption-" + choice.optionIndex(option)));
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].method, "displayPolicy.set");
        const acknowledged = JSON.parse(JSON.stringify(initial));
        acknowledged.policy.prefer_external = data.preferExternal;
        acknowledged.status = "pending";
        acknowledged.docking_state = "applying";
        c.applyDisplayPolicy(acknowledged);
        c.requestFinished(calls[0].id);
        verify(c.dockingApplying && !c.canEdit && !choice.interactive);
        verify(!c.setPreferExternal(!data.preferExternal));
        verify(!c.executeOutputAction("toggle-enabled", "eDP-1"));
        verify(waitForPolish(panel.Window.window));
        verify(!findChild(panel, "detailAction:toggle-enabled").enabled);
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(!c.dirty, "a saved preference is not observed enablement");
        compare(calls.length, 1);
        const observed = JSON.parse(JSON.stringify(acknowledged));
        observed.outputs[0].disabled = data.preferExternal;
        observed.status = data.preferExternal ? "external" : "all-displays";
        observed.docking_state = "settled";
        observed.baseline = "observed-docking-baseline";
        c.applyDisplayPolicy(observed);
        verify(c.canEdit && !c.stale);
        compare(c.baselineToken, observed.baseline);
        tryVerify(() => findChild(panel, "detailAction:toggle-enabled").enabled);
        mouseClick(findChild(panel, "detailAction:toggle-enabled"));
        verify(c.dirty && !c.stale);
        compare(c.selectedDraft.enabled, data.preferExternal);
        verify(c.preview());
        compare(calls[1].method, "displayLayout.preview");
        compare(calls[1].params.baseline, observed.baseline);
    }
    function test_failedDockingAllowsExplicitSamePreferenceRetryAndManualRecovery() {
        const panel = makePanel();
        const c = panel.controller;
        const failed = displayState();
        failed.docking_state = "failed";
        failed.status = "error";
        failed.error = "Docking change was not observed";
        c.applyDisplayPolicy(failed);
        c.uiActive = true;
        c.selectOutput("eDP-1");
        c.openDetails();
        waitForDetails(panel);
        const choice = findChild(panel, "dockedLaptopBehavior");
        compare(choice.value, "failed");
        verify(!choice.options[choice.currentIndex].enabled);
        verify(c.canEdit && choice.interactive, "failure releases controls for explicit recovery");
        verify(c.statusMessage.includes("not observed"));
        mouseClick(choice);
        tryCompare(choice.popup, "visible", true);
        mouseClick(findChild(choice.popup.contentItem, "dropDownOption-" + choice.optionIndex("auto-off")));
        keyClick(Qt.Key_Return);
        compare(calls.length, 1, "retrying the same stored preference must not be a no-op");
        compare(calls[0].method, "displayPolicy.set");
        compare(calls[0].params.prefer_external, true);
        const retry = JSON.parse(JSON.stringify(failed));
        retry.docking_state = "applying";
        retry.status = "pending";
        retry.error = null;
        c.applyDisplayPolicy(retry);
        c.requestFinished(calls[0].id);
        verify(!c.canEdit && !choice.interactive);
        c.applyDisplayPolicy(failed);
        tryVerify(() => findChild(panel, "detailAction:toggle-enabled").enabled);
        mouseClick(findChild(panel, "detailAction:toggle-enabled"));
        verify(c.dirty && !c.stale);
        compare(calls.length, 1, "manual recovery is still draft-only until Preview");
        verify(!choice.interactive, "a manual draft still excludes docking writes");
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
        compare(calls[0].params.baseline, "opaque-native-baseline");
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
}
