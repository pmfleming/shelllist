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
        const info = findChild(panel, "sleepDetailsButton");
        verify(info.enabled, "explanations remain accessible when actions are unavailable");
        mouseClick(info);
        const popup = findChild(panel, "sleepDetailsPopup");
        verify(popup !== null);
        tryCompare(popup, "opened", true);
        verify(panel.controller.sleepDetailsOpen);
        const capability = findChild(popup.contentItem, "sleepCapability-hibernate");
        compare(capability.text, "Not supported by the system");
        compare(findChild(popup.contentItem, "sleepHandlerName").text, "Network");
        const explanation = findChild(popup.contentItem, "sleepHandlerReason");
        compare(explanation.text, reason);
        compare(explanation.elide, Text.ElideNone);
        const scroll = popup.contentItem;
        tryVerify(function () { return scroll.contentHeight > scroll.height; });
        verify(popup.width <= testCase.width);
        verify(popup.height <= testCase.height);
        popup.close();
        tryCompare(popup, "opened", false);
        tryCompare(info, "activeFocus", true);
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

    function test_popupEscapeDoesNotDismissPanelAndTabChangeClosesDetails() {
        const panel = makePanel();
        panel.controller.backend.active = false;
        panel.controller.uiActive = true;
        const closeSpy = createTemporaryObject(closeSpyComponent, testCase, { target: panel.controller });
        const info = findChild(panel, "sleepDetailsButton");
        info.forceActiveFocus();
        keyClick(Qt.Key_Space);
        const popup = findChild(panel, "sleepDetailsPopup");
        tryCompare(popup, "opened", true);
        keyClick(Qt.Key_Escape);
        tryCompare(popup, "opened", false);
        compare(closeSpy.count, 0, "Escape closes the details, not the battery panel");
        verify(!panel.controller.sleepDetailsOpen);
        popup.open();
        tryCompare(popup, "opened", true);
        panel.controller.selectViewTab("overview");
        tryCompare(popup, "opened", false);
        verify(!panel.controller.sleepDetailsOpen);
    }
}
