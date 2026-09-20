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
    function state() {
        return { available: true, policy: { prefer_external: true }, status: "external", layout: { saved: { outputs: [] }, trial: null },
            outputs: [{ name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: true, availableModes: ["1920x1200@60.00Hz"] },
                { name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, availableModes: ["3840x2160@60.00Hz"] }] };
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applyDisplayPolicy(state());
        verify(waitForRendering(panel));
        calls = [];
        return panel;
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
        c.applyDisplayPolicy(state());
        verify(c.canChange);
    }
    function test_trialTokensAndHiddenPreviewRevert() {
        const c = makePanel().controller;
        const value = state();
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
        verify(c.displayLayoutAction("preview", { outputs: [] }));
        c.deactivateUi();
        const value = state();
        value.layout.trial = { id: "late-token", expires_at: Date.now() / 1000 + 20 };
        c.applyDisplayPolicy(value);
        compare(calls.length, 1, "wait for preview acknowledgement before sending revert");
        c.requestFinished(calls[0].id);
        compare(calls.length, 2);
        compare(calls[1].method, "displayLayout.revert");
        compare(calls[1].params.id, "late-token");
    }
}
