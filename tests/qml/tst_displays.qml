pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Displays as Displays
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "Displays"
    when: windowShown
    visible: true
    width: 1040
    height: 780
    property var originalFactory
    property var originalSessions
    property var calls: []

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError, var route)
            signal eventReceived(var event, var route)
            signal transportFailed(string message)
            function call(id, method, params, route) { testCase.calls = testCase.calls.concat([{ id: id, method: method, params: params }]); }
            function subscribeExtra(id, streams, route) {}
            function cancel(id, requestId, route) {}
            function release(id, route) {}
        }
    }
    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }
    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions)) session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }
    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            Displays.DisplayController { id: controller }
            Displays.DisplayContent { controller: panel.controller }
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
    function test_providerResultsAndLiveActions() {
        const c = makePanel().controller;
        const provider = c.displayProvider;
        const results = provider.resultsForOutputs(c.outputs);
        compare(results.length, 2);
        compare(results[0].key, "displays::eDP-1");
        verify(results[0].subtitle.indexOf("Disabled") >= 0);
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
    function test_policyIsAcknowledgedAndDisplayOnly() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.setPreferExternal(false));
        compare(calls.length, 1);
        compare(calls[0].method, "displayPolicy.set");
        compare(calls[0].params.prefer_external, false);
        verify(c.displayPolicyState.policy.prefer_external);
        verify(!c.setPreferExternal(false));
        c.requestFailed(calls[0].id, "disk full");
        compare(c.displayPolicyError, "disk full");
        verify(c.canChange);
        c.transportFailed("disconnected");
        verify(!c.canChange);
        c.applyDisplayPolicy(displayState());
        verify(c.canChange);
    }
    function test_diagramSummaryAndWorkspaceKeyboard() {
        const panel = makePanel();
        const c = panel.controller;
        compare(c.activeCount, 1, "summary shows actual state, not the fallback preview draft");
        verify(c.draft[0].enabled, "preview retains laptop fallback");
        verify(findChild(panel, "displayOverviewCanvas") !== null);
        verify(findChild(panel, "preferExternalDisplay").Accessible.name.length > 0);
        c.uiActive = true;
        c.selectOutput("DP-1");
        c.openDetails();
        verify(waitForRendering(panel));
        const canvas = findChild(panel, "displayWorkspaceCanvas");
        verify(canvas !== null);
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
        verify(waitForRendering(panel));
        const page = findChild(panel, "displayLayoutWorkspace");
        const enabled = findChild(panel, "displayEnabled");
        enabled.forceActiveFocus();
        tryVerify(function () { return page.contentY > 0; });
        const position = enabled.mapToItem(page, 0, 0);
        verify(position.y >= 0);
        verify(position.y + enabled.height <= page.height + 1);
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
    function test_desktopOnlyAndUnavailableStates() {
        const panel = makePanel();
        const c = panel.controller;
        const value = displayState();
        value.outputs.shift();
        c.applyDisplayPolicy(value);
        verify(!findChild(panel, "displayPolicyCard").visible);
        c.edit("DP-1", "enabled", false);
        verify(!c.canPreview, "desktop cannot disable its last output");
        c.reloadDraft();
        c.edit("DP-1", "x", "1536");
        verify(!c.dirty, "equivalent numeric field edits are not changes");
        value.available = false;
        c.applyDisplayPolicy(value);
        verify(!c.canChange);
        verify(c.statusMessage.indexOf("programs.shelllist.displays.enable") >= 0);
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
