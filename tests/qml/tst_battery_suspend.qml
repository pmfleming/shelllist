pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Battery as Battery
import Shelllist.Io as Io
import Shelllist.Ui as Ui

DaemonTestCase {
    id: testCase
    name: "BatterySuspend"
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
            Battery.BatteryController {
                id: controller
                uiActive: true
            }
            Battery.BatteryContent {
                objectName: "batterySurface"
                controller: panel.controller
            }
        }
    }

    function suspendState(inhibitors) {
        return {
            available: true,
            can_suspend: "yes",
            can_hibernate: "na",
            lock_before_sleep: true,
            keep_awake: false,
            preparing_for_sleep: false,
            inhibitors: inhibitors || []
        };
    }

    function makePanel(inhibitors) {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applyPowerProfile({
            available: true,
            profile: "balanced",
            profiles: [
                {
                    name: "power-saver"
                },
                {
                    name: "balanced"
                },
                {
                    name: "performance"
                }
            ],
            battery_automation: {
                status: "waiting"
            }
        });
        panel.controller.applyPowerSuspend(suspendState(inhibitors));
        panel.controller.selectViewTab("power");
        verify(waitForRendering(panel));
        const page = findChild(panel, "batteryDetailPage");
        page.contentY = Math.max(0, page.contentHeight - page.height);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_degradedTelemetryAllowsOnlyReleaseThroughKeyboardAndAccessibility() {
        const panel = makePanel();
        const controller = panel.controller;
        const button = findChild(panel, "keepAwakeButton");
        const client = Io.DaemonSessions.sessions["bar-daemon"].client;
        controller.applyPowerSuspend({
            available: false,
            keep_awake: false,
            preparing_for_sleep: true
        });
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
        controller.applyPowerSuspend(suspendState());
        calls = [];
        button.Accessible.toggleAction();
        compare(calls.length, 1);
        compare(calls[0].params.enabled, true, "healthy telemetry restores ordinary toggling");
        verify(!button.Accessible.checked, "sending is not acknowledgement");
        controller.operationFinished("power-keep-awake-3");
        controller.applyPowerSuspend(Object.assign(suspendState(), {keep_awake: true, can_hibernate: "yes"}));
        verify(button.Accessible.checked && button.enabled, "acknowledged Keep awake can still be released");
        compare(button.iconColor, button.labelColor, "active fill retains its contrasting foreground");
        compare(button.backgroundColor, Ui.Theme.accent);
        verify(findChild(panel, "suspendAction-lock").enabled);
        verify(!findChild(panel, "suspendAction-suspend").enabled);
        verify(!findChild(panel, "suspendAction-hibernate").enabled);
    }

}
