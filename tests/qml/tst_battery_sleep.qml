pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Battery as Battery

TestCase {
    id: testCase
    name: "BatterySleep"
    when: windowShown
    visible: true
    width: 420
    height: 760

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
            lock_before_sleep: true, preparing_for_sleep: false, inhibitors: inhibitors || [] };
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
        compare(controller.lastError, "");
        const retry = findChild(panel, "sleepRetryButton");
        verify(retry.visible && retry.enabled);
        compare(retry.Accessible.name, "Retry Suspend");
        controller.operationFinished("power-sleep-suspend-2");
        verify(!retry.visible);
        verify(!findChild(panel, "sleepStatusRow").visible);
    }

    function test_sharedAndSeparateAutomaticSleepControls() {
        const panel = makePanel();
        const state = {
            available: true, active_profile: "battery", hibernate_available: true,
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
