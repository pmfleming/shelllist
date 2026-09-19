pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Battery as Battery
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "BatterySleep"
    when: windowShown
    visible: true
    width: 420
    height: 760
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
            Battery.BatteryController { id: controller }
            Battery.BatteryContent { controller: panel.controller }
        }
    }

    Component {
        id: closeSpyComponent
        SignalSpy { signalName: "closeWindowRequested" }
    }

    function sleepState(inhibitors) {
        return { available: true, can_suspend: "yes", can_hibernate: "na",
            lock_before_sleep: true, keep_awake: false, preparing_for_sleep: false, inhibitors: inhibitors || [] };
    }

    function makePanel(inhibitors) {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applyPowerProfile({ available: true, profile: "balanced",
            profiles: [{ name: "power-saver" }, { name: "balanced" }, { name: "performance" }],
            battery_automation: { status: "waiting" } });
        panel.controller.applyPowerSleep(sleepState(inhibitors));
        panel.controller.selectViewTab("power");
        verify(waitForRendering(panel));
        const page = findChild(panel, "batteryDetailPage");
        page.contentY = Math.max(0, page.contentHeight - page.height);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_normalHandlersStayHiddenAndUnavailableActionsAreExplained() {
        const reason = "Disconnecting network connections cleanly before sleeping. ".repeat(60);
        const panel = makePanel([
            { what: "sleep", mode: "delay", who: "NetworkManager", why: reason },
            { what: "shutdown", mode: "block", who: "Updater", why: "Installing updates" },
            { what: "handle-lid-switch", mode: "block", who: "Desktop", why: "Owns lid behaviour" }
        ]);
        const card = findChild(panel, "powerSleepCard");
        verify(card.height <= 80, "normal sleep handlers must not expand the one-row card");
        verify(!findChild(panel, "sleepStatusRow").visible);
        for (const action of ["lock", "suspend", "hibernate"]) {
            const button = findChild(panel, "sleepAction-" + action);
            compare(button.label, "");
            verify(button.icon.length > 0);
            verify(button.Accessible.name.length > 0);
            verify(button.toolTip.length > 0);
            verify(button.mapToItem(card, button.width, 0).x <= card.width - card.contentPadding);
        }
        verify(!findChild(panel, "sleepAction-hibernate").enabled);
        verify(findChild(panel, "sleepAction-hibernate").toolTip.indexOf("Not supported by the system") >= 0);
        verify(findChild(panel, "sleepDetailsButton") === null);
        verify(findChild(panel, "sleepDetailsPopup") === null);
    }

    function test_onlyRealBlockersWarnAndProgressErrorsStayLocal() {
        const panel = makePanel([{ what: "shutdown:sleep", mode: "block", who: "Editor", why: "Saving document" }]);
        const controller = panel.controller;
        const status = findChild(panel, "sleepStatusText");
        verify(findChild(panel, "sleepStatusRow").visible);
        compare(status.text, "Sleep blocked");
        controller.applyPowerSleep(sleepState([{ what: "sleep", mode: "delay", who: "NetworkManager" }]));
        verify(!findChild(panel, "sleepStatusRow").visible);
        controller.sleepPendingAction = "suspend";
        controller.sleepRetryAction = "suspend";
        controller.actionInFlight = true;
        compare(status.text, "Locking…");
        for (const action of ["lock", "suspend", "hibernate"])
            verify(!findChild(panel, "sleepAction-" + action).enabled);
        controller.applyPowerSleep(Object.assign(sleepState(), { preparing_for_sleep: true }));
        compare(status.text, "Preparing sleep…");
        controller.applyPowerSleep(sleepState());
        controller.operationFailed("power-sleep-suspend-1", "Screen lock was not confirmed");
        compare(status.text, "Suspend failed");
        const reason = findChild(panel, "sleepFailureReason");
        verify(reason.visible);
        compare(reason.text, "Screen lock was not confirmed");
        compare(reason.elide, Text.ElideNone);
        compare(controller.lastError, "");
        const retry = findChild(panel, "sleepRetryButton");
        verify(retry.visible && retry.enabled);
        compare(retry.Accessible.name, "Retry Suspend");
        controller.operationFinished("power-sleep-suspend-2");
        verify(!reason.visible);
        verify(!retry.visible);
        verify(!findChild(panel, "sleepStatusRow").visible);
    }

    function test_keepAwakeIsAccessibleAndOnlyDisablesSleep() {
        const panel = makePanel();
        const controller = panel.controller;
        const button = findChild(panel, "keepAwakeButton");
        const card = findChild(panel, "powerSleepCard");
        verify(button.enabled);
        compare(button.Accessible.name, "Keep awake");
        verify(button.Accessible.checkable);
        verify(!button.Accessible.checked);
        verify(button.toolTip.indexOf("locking and screen blanking continue") >= 0);
        verify(button.mapToItem(card, button.width, 0).x <= card.width - card.contentPadding);
        controller.applyPowerSleep(Object.assign(sleepState(), { keep_awake: true, can_hibernate: "yes" }));
        verify(button.Accessible.checked);
        compare(button.tone, "accent");
        verify(button.enabled, "must be able to turn it off");
        verify(findChild(panel, "sleepAction-lock").enabled);
        verify(!findChild(panel, "sleepAction-suspend").enabled);
        verify(!findChild(panel, "sleepAction-hibernate").enabled);
        compare(findChild(panel, "sleepStatusText").text, "Keep awake on · sleep & hibernate blocked");
        controller.keepAwakePending = true;
        controller.actionInFlight = true;
        verify(!button.enabled);
        compare(findChild(panel, "keepAwakeStatus").text, "Updating Keep awake…");
        controller.operationFailed("power-keep-awake-1", "Permission denied");
        verify(button.enabled);
        compare(findChild(panel, "keepAwakeStatus").text, "Permission denied");
        verify(!findChild(panel, "sleepRetryButton").visible);
        controller.applyPowerSleep(sleepState());
        verify(!button.Accessible.checked);
        verify(findChild(panel, "sleepAction-suspend").enabled);
        button.forceActiveFocus();
        verify(button.activeFocus);
        const oldDaemon = sleepState();
        delete oldDaemon.keep_awake;
        controller.applyPowerSleep(oldDaemon);
        verify(!button.enabled);
        verify(button.toolTip.indexOf("updated bar-daemon") >= 0);
    }

    function test_degradedTelemetryAllowsOnlyReleaseThroughKeyboardAndAccessibility() {
        const panel = makePanel();
        const controller = panel.controller;
        const button = findChild(panel, "keepAwakeButton");
        const client = Io.DaemonSessions.sessions["bar-daemon"].client;
        controller.applyPowerSleep({ available: false, keep_awake: false, preparing_for_sleep: true });
        verify(button.enabled, "even a default false snapshot must allow releasing an existing FD");
        verify(button.toolTip.indexOf("turn off Keep awake") >= 0);
        calls = [];
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setKeepAwake");
        compare(calls[0].params.enabled, false);
        verify(!button.enabled);
        controller.operationFinished("power-keep-awake-1");
        button.Accessible.toggleAction();
        compare(calls.length, 2);
        compare(calls[1].params.enabled, false);
        controller.operationFinished("power-keep-awake-2");
        client.ready = false;
        verify(!button.enabled);
        verify(button.toolTip.indexOf("Reconnect") >= 0);
        client.ready = true;
        verify(button.enabled);
        controller.applyPowerSleep(sleepState());
        calls = [];
        button.Accessible.toggleAction();
        compare(calls.length, 1);
        compare(calls[0].params.enabled, true, "healthy telemetry restores ordinary toggling");
    }

    function test_displayPreferenceIsDaemonOwnedAndRecoveryStatusIsVisible() {
        const panel = makePanel();
        const controller = panel.controller;
        const toggle = findChild(panel, "preferExternalDisplay");
        const status = findChild(panel, "displayPolicyStatus");
        verify(!toggle.interactive);
        controller.applyDisplayPolicy({ available: true, policy: { prefer_external: true }, status: "settling" });
        verify(toggle.checked);
        verify(toggle.interactive);
        verify(status.text.indexOf("stable") >= 0);
        verify(toggle.Accessible.name.length > 0);
        calls = [];
        toggle.clicked();
        compare(calls.length, 1);
        compare(calls[0].method, "displayPolicy.set");
        compare(calls[0].params.prefer_external, false);
        verify(toggle.checked, "wait for the daemon confirmation");
        verify(!toggle.interactive);
        controller.operationFailed("display-policy-1", "Permission denied");
        compare(status.text, "Permission denied");
        verify(toggle.interactive);
        controller.operationFinished("display-policy-2");
        controller.applyDisplayPolicy({ available: true, policy: { prefer_external: false }, status: "all-displays" });
        verify(!toggle.checked);
        verify(status.text.indexOf("Laptop screen enabled") >= 0);
    }

    function test_sharedAndSeparateAutomaticSleepControls() {
        const panel = makePanel();
        const state = {
            available: true, active_profile: "battery", hibernate_available: true,
            lid: { available: true, managed: false, error: null },
            policy: {
                same_profile: false,
                battery: { sleep_minutes: 15, hibernate_minutes: 60 },
                plugged: { sleep_minutes: 45, hibernate_minutes: 180 }
            }
        };
        panel.controller.applySleepPolicy(state);
        verify(waitForRendering(panel));
        compare(findChild(panel, "sleepDelay-battery").value, "15");
        compare(findChild(panel, "hibernateDelay-battery").value, "60");
        compare(findChild(panel, "sleepDelay-plugged").value, "45");
        compare(findChild(panel, "hibernateDelay-plugged").value, "180");
        const lid = findChild(panel, "lidCloseAction");
        compare(lid.value, "system", "older policies retain logind behavior");
        verify(lid.Accessible.name.length > 0);
        compare(lid.options.length, 6);
        const card = findChild(panel, "automaticSleepCard");
        for (const name of ["sleepDelay-battery", "hibernateDelay-battery", "sleepDelay-plugged", "hibernateDelay-plugged"]) {
            const control = findChild(panel, name);
            verify(control.enabled);
            verify(control.Accessible.name.length > 0);
            verify(control.mapToItem(card, control.width, 0).x <= card.width - card.contentPadding);
        }
        state.policy.same_profile = true;
        state.policy.battery.sleep_minutes = 0;
        panel.controller.applySleepPolicy(JSON.parse(JSON.stringify(state)));
        verify(waitForRendering(panel));
        verify(findChild(panel, "sleepDelay-plugged") === null);
        compare(findChild(panel, "sleepDelay-battery").value, "0");
        verify(!findChild(panel, "hibernateDelay-battery").enabled);
        state.policy.lid_action = "profile";
        panel.controller.applySleepPolicy(JSON.parse(JSON.stringify(state)));
        compare(lid.value, "profile");
        verify(findChild(panel, "hibernateDelay-battery").enabled, "lid profile works with Never idle sleep");
        state.lid.error = "Lid action failed: lock was not confirmed";
        panel.controller.applySleepPolicy(JSON.parse(JSON.stringify(state)));
        compare(findChild(panel, "lidCloseStatus").text, state.lid.error);
        state.policy.battery.sleep_minutes = 15;
        state.hibernate_available = false;
        panel.controller.applySleepPolicy(JSON.parse(JSON.stringify(state)));
        const hibernate = findChild(panel, "hibernateDelay-battery");
        verify(hibernate.options.every(function (option) { return option.enabled === (option.value === "0"); }));
        state.available = false;
        panel.controller.applySleepPolicy(JSON.parse(JSON.stringify(state)));
        verify(!findChild(panel, "sleepDelay-battery").enabled);
        verify(!findChild(panel, "sleepSameProfile").interactive);
    }

    function test_keyboardNavigationAndEscapeRemainAvailable() {
        const panel = makePanel();
        panel.controller.backend.active = false;
        panel.controller.uiActive = true;
        const closeSpy = createTemporaryObject(closeSpyComponent, testCase, { target: panel.controller });
        findChild(panel, "sleepAction-lock").forceActiveFocus();
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(panel.controller.viewTab, "overview");
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 1, "Escape dismisses the battery panel directly");
    }
}
