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
    function test_profilesUseGlobalCogAndPerDisplayRequirements() {
        const panel = makePanel(), c = panel.controller;
        const state = displayState();
        const profile = {name: "Home", layout: {outputs: []}, required: ["DP-1"], priority: 0, plugged: null, lid_closed: null};
        state.layout.profiles = {items: [profile], automatic: false, active: "Home", fallback: null};
        state.profile_bindings = {"DP-1": "DP-1"};
        c.applyDisplayPolicy(state); c.uiActive = true;
        c.openGlobalSettings(); c.selectFocusPage("profiles"); waitForDetails(panel);
        const power = findChild(panel, "displayProfile-plugged"); verify(power !== null && power.visible);
        power.selected("no");
        compare(calls.length, 1); compare(calls[0].method, "displayProfiles.set");
        compare(calls[0].params.plugged, false); compare(calls[0].params.operation, "update");
        c.requestFinished(calls[0].id);
        c.selectOutput("DP-1"); c.openDetails(); waitForDetails(panel);
        const required = findChild(panel, "displayProfileRequired"); verify(required.visible);
        required.selected("no"); compare(calls[1].params.required.length, 0);
        c.requestFinished(calls[1].id);
        c.openGlobalSettings(); c.selectFocusPage("profiles");
        verify(c.profileRequest({operation: "preview", name: "Home"}));
        compare(c.pendingAction, "profilePreview");
        c.deactivateUi(); verify(c.revertOnArrival, "closing a pending profile preview must revert its receipt");
    }
    function test_relativePlacementFieldsRemainDraftOnly() {
        const panel = makePanel(), c = panel.controller;
        c.uiActive = true;
        const state = displayState(); state.outputs[0].disabled = false;
        c.applyDisplayPolicy(state); c.selectOutput("DP-1"); c.openDetails(); waitForDetails(panel);
        const mode = findChild(panel, "displayPositionMode"); verify(mode !== null);
        mode.selected("relative");
        compare(c.selectedDraft.relative.reference, "eDP-1");
        compare(c.selectedDraft.x, 1536);
        c.edit("eDP-1", "scale", 2);
        compare(c.selectedDraft.x, 960);
        compare(calls.length, 0);
        const gap = findChild(panel, "displayRelativeGap");
        gap.focusInput(true); keyClick(Qt.Key_2); keyClick(Qt.Key_4); keyClick(Qt.Key_Escape);
        compare(c.selectedDraft.relative.gap, 0);
        gap.focusInput(true); keyClick(Qt.Key_2); keyClick(Qt.Key_4); keyClick(Qt.Key_Return);
        compare(c.selectedDraft.relative.gap, 24);
        compare(c.selectedDraft.x, 984);
        compare(calls.length, 0);
        findChild(panel, "displayIdentityMatch").selected("connector");
        verify(c.selectedDraft.match_connector);
        verify(c.preview()); compare(calls.length, 1);
    }
    function test_advancedSettingsUseObservedChoicesAndTheWholeLayoutTrial() {
        const panel = makePanel(), c = panel.controller;
        c.uiActive = true;
        const state = displayState();
        state.outputs[1].advanced_observed = {vrr: false, bit_depth: 8, color: "srgb", sdr_brightness: 1, sdr_saturation: 1};
        state.outputs[1].advanced_options = {vrr: [false, true], bit_depth: [8, 10], color: ["srgb", "hdr"], sdr_brightness: true, sdr_saturation: true};
        c.applyDisplayPolicy(state); c.selectOutput("DP-1"); c.openDetails(); waitForDetails(panel);
        compare(Object.keys(c.selectedDraft.advanced).length, 0);
        findChild(panel, "displayAdvanced-vrr").selected("true");
        findChild(panel, "displayAdvanced-bit_depth").selected("10");
        findChild(panel, "displayAdvanced-color").selected("hdr");
        const brightness = findChild(panel, "displayAdvanced-sdr_brightness");
        tryVerify(() => brightness.visible);
        brightness.focusInput(true); keyClick(Qt.Key_2); keyClick(Qt.Key_Escape);
        verify(c.selectedDraft.advanced.sdr_brightness === undefined);
        brightness.focusInput(true); keyClick(Qt.Key_2); keyClick(Qt.Key_Return);
        compare(c.selectedDraft.advanced.sdr_brightness, 2);
        compare(calls.length, 0);
        verify(c.preview()); compare(calls.length, 1);
        const submitted = calls[0].params.outputs.find(o => o.name === "DP-1");
        compare(submitted.advanced, {vrr: true, bit_depth: 10, color: "hdr", sdr_brightness: 2});
    }
    function test_unknownAdvancedCapabilitiesStayUnavailable() {
        const panel = makePanel(), c = panel.controller;
        c.uiActive = true; c.selectOutput("DP-1"); c.openDetails(); waitForDetails(panel);
        verify(!findChild(panel, "displayAdvanced-vrr").interactive);
        verify(!findChild(panel, "displayAdvanced-color").interactive);
        verify(!findChild(panel, "displayAdvanced-bit_depth").interactive);
        compare(calls.length, 0);
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
        verify(c.canPreview, "draft validity is decided by Rust on explicit Preview; editing never writes");
        keyClick(Qt.Key_R, Qt.AltModifier);
        verify(c.canPreview, "placing the enabled laptop beside the external display clears the overlap");
        verify(c.selectedDraft.x > 0);
        c.selectOutput("DP-1");
        tryVerify(() => power()?.enabled);
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(!c.selectedDraft.enabled && c.canPreview);
        compare(calls.length, 0, "the swap still needs a single guarded Preview");
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
        verify("modes" in calls[0].params.outputs[1], "raw draft reaches the native normalizer without frontend payload policy");
        verify("internal" in calls[0].params.outputs[1]);
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
}
