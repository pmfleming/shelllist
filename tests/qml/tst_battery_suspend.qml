pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Battery as Battery
import Shelllist.Io as Io

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
        verify(findChild(panel, "suspendAction-lock").enabled);
        verify(!findChild(panel, "suspendAction-suspend").enabled);
        verify(!findChild(panel, "suspendAction-hibernate").enabled);
    }

    function test_criticalProtectionControlsAndUnknownOutcome() {
        const panel = makePanel();
        const state = {
            available: false,
            policy: {
                same_profile: true,
                battery: {
                    sleep_minutes: 30,
                    hibernate_minutes: 0
                },
                plugged: {
                    sleep_minutes: 30,
                    hibernate_minutes: 0
                },
                critical_battery: {
                    enabled: false,
                    percent: 5,
                    grace_seconds: 60
                }
            },
            critical_battery: {
                phase: "disabled",
                remaining_seconds: 0
            }
        };
        panel.controller.applySuspendPolicy(state);
        verify(!findChild(panel, "criticalBatteryEnabled").checked);
        compare(findChild(panel, "criticalBatteryPercent").value, "5");
        state.policy.critical_battery.enabled = true;
        state.critical_battery = {
            phase: "countdown",
            remaining_seconds: 45
        };
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        verify(findChild(panel, "criticalBatteryStatus").text.includes("45"));
        verify(findChild(panel, "criticalBatteryCancel").visible);
        panel.controller.applyPowerSuspend(Object.assign(suspendState(), {
            operation: {
                phase: "unknown",
                error: "reply lost"
            }
        }));
        panel.controller.suspendError = "reply lost";
        verify(!findChild(panel, "suspendRetryButton").visible);
        verify(findChild(panel, "suspendStatusText").text.includes("outcome unknown"));
    }

    function test_suspendNamesPreserveDaemonWireContract() {
        const panel = makePanel();
        const controller = panel.controller;
        const backend = controller.backend;
        const state = {
            available: true,
            policy: {
                same_profile: true,
                battery: {
                    sleep_minutes: 30,
                    hibernate_minutes: 60
                },
                plugged: {
                    sleep_minutes: 45,
                    hibernate_minutes: 180
                }
            }
        };
        verify(backend.streams.includes("power-sleep.changed"));
        verify(backend.streams.includes("sleep-policy.changed"));
        backend.applyData({
            snapshot: {
                power_sleep: suspendState(),
                sleep_policy: state
            }
        });
        verify(controller.powerSuspend.available);
        compare(controller.suspendPolicyDraft.battery.sleep_minutes, 30);
        calls = [];
        verify(controller.updateSuspendPolicy("battery", "sleep_minutes", 15));
        compare(calls.length, 1);
        compare(calls[0].method, "powerSleep.setPolicy");
        compare(calls[0].params.battery.sleep_minutes, 15);
        compare(calls[0].params.battery.hibernate_minutes, 60);
        compare(calls[0].params.plugged.hibernate_minutes, 180);
        verify(controller.suspendPolicySaving);
        Io.DaemonSessions.sessions["bar-daemon"].client.response(calls[0].id, {
            protocol: backend.expectedProtocol,
            version: backend.expectedVersion,
            ok: true,
            data: {
                sleep_policy: {
                    available: true,
                    policy: calls[0].params
                }
            }
        }, "", calls[0].route);
        verify(!controller.suspendPolicySaving);
        verify(!controller.suspendPolicyDirty);
        compare(controller.suspendPolicyDraft.battery.sleep_minutes, 15);
        controller.handleEvent({
            event: "changed",
            stream: "power-sleep.changed",
            data: Object.assign(suspendState(), {
                keep_awake: true
            })
        });
        verify(controller.keepAwake);
        controller.handleEvent({
            event: "changed",
            stream: "sleep-policy.changed",
            data: state
        });
        compare(controller.suspendPolicyDraft.battery.sleep_minutes, 30);
    }

}
