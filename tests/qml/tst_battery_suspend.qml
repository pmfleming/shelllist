pragma ComponentBehavior: Bound

import QtQuick
import QtTest
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
                controller: panel.controller
            }
        }
    }

    Component {
        id: closeSpyComponent
        SignalSpy {
            signalName: "closeWindowRequested"
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

    function test_onlyRealBlockersWarnAndProgressErrorsStayLocal() {
        const panel = makePanel([
            {
                what: "shutdown:sleep",
                mode: "block",
                who: "Editor",
                why: "Saving document"
            }
        ]);
        const controller = panel.controller;
        const status = findChild(panel, "suspendStatusText");
        verify(findChild(panel, "suspendStatusRow").visible);
        compare(status.text, "Suspend blocked");
        controller.applyPowerSuspend(suspendState([
            {
                what: "sleep",
                mode: "delay",
                who: "NetworkManager"
            }
        ]));
        verify(!findChild(panel, "suspendStatusRow").visible);
        controller.suspendPendingAction = "suspend";
        controller.suspendRetryAction = "suspend";
        controller.actionInFlight = true;
        compare(status.text, "Locking…");
        for (const action of ["lock", "suspend", "hibernate"])
            verify(!findChild(panel, "suspendAction-" + action).enabled);
        controller.applyPowerSuspend(Object.assign(suspendState(), {
            preparing_for_sleep: true
        }));
        compare(status.text, "Preparing suspend…");
        controller.applyPowerSuspend(suspendState());
        controller.operationFailed("power-suspend-suspend-1", "Screen lock was not confirmed");
        compare(status.text, "Suspend failed");
        const reason = findChild(panel, "suspendFailureReason");
        verify(reason.visible);
        compare(reason.text, "Screen lock was not confirmed");
        compare(reason.elide, Text.ElideNone);
        compare(controller.lastError, "");
        const retry = findChild(panel, "suspendRetryButton");
        verify(retry.visible && retry.enabled);
        compare(retry.Accessible.name, "Retry Suspend");
        controller.operationFinished("power-suspend-suspend-2");
        verify(!reason.visible);
        verify(!retry.visible);
        verify(!findChild(panel, "suspendStatusRow").visible);
    }

    function test_keepAwakeIsAccessibleAndOnlyDisablesSuspend() {
        const panel = makePanel();
        const controller = panel.controller;
        const button = findChild(panel, "keepAwakeButton");
        const card = findChild(panel, "powerSuspendCard");
        verify(button.enabled);
        compare(button.Accessible.name, "Keep awake");
        verify(button.Accessible.checkable);
        verify(!button.Accessible.checked);
        verify(button.toolTip.indexOf("locking and screen blanking continue") >= 0);
        verify(button.mapToItem(card, button.width, 0).x <= card.width - card.contentPadding);
        controller.applyPowerSuspend(Object.assign(suspendState(), {
            keep_awake: true,
            can_hibernate: "yes"
        }));
        verify(button.Accessible.checked);
        compare(button.tone, "accent");
        verify(button.enabled, "must be able to turn it off");
        verify(findChild(panel, "suspendAction-lock").enabled);
        verify(!findChild(panel, "suspendAction-suspend").enabled);
        verify(!findChild(panel, "suspendAction-hibernate").enabled);
        compare(findChild(panel, "suspendStatusText").text, "Keep awake on · suspend & hibernate blocked");
        controller.keepAwakePending = true;
        controller.actionInFlight = true;
        verify(!button.enabled);
        compare(findChild(panel, "keepAwakeStatus").text, "Updating Keep awake…");
        controller.operationFailed("power-keep-awake-1", "Permission denied");
        verify(button.enabled);
        compare(findChild(panel, "keepAwakeStatus").text, "Permission denied");
        verify(!findChild(panel, "suspendRetryButton").visible);
        controller.applyPowerSuspend(suspendState());
        verify(!button.Accessible.checked);
        verify(findChild(panel, "suspendAction-suspend").enabled);
        button.forceActiveFocus();
        verify(button.activeFocus);
        const oldDaemon = suspendState();
        delete oldDaemon.keep_awake;
        controller.applyPowerSuspend(oldDaemon);
        verify(!button.enabled);
        verify(button.toolTip.indexOf("updated bar-daemon") >= 0);
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
    }

    function test_sharedAndSeparateAutomaticSuspendControls() {
        const panel = makePanel();
        const state = {
            available: true,
            active_profile: "battery",
            hibernate_available: true,
            lid: {
                available: true,
                managed: false,
                error: null
            },
            policy: {
                same_profile: false,
                battery: {
                    sleep_minutes: 15,
                    hibernate_minutes: 60
                },
                plugged: {
                    sleep_minutes: 45,
                    hibernate_minutes: 180
                }
            }
        };
        panel.controller.applySuspendPolicy(state);
        verify(waitForRendering(panel));
        compare(findChild(panel, "suspendDelay-battery").value, "15");
        compare(findChild(panel, "hibernateDelay-battery").value, "60");
        compare(findChild(panel, "suspendDelay-plugged").value, "45");
        compare(findChild(panel, "hibernateDelay-plugged").value, "180");
        const lid = findChild(panel, "lidCloseAction");
        compare(lid.value, "system", "older policies retain logind behavior");
        verify(lid.Accessible.name.length > 0);
        compare(lid.options.length, 6);
        const card = findChild(panel, "automaticSuspendCard");
        for (const name of ["suspendDelay-battery", "hibernateDelay-battery", "suspendDelay-plugged", "hibernateDelay-plugged"]) {
            const control = findChild(panel, name);
            verify(control.enabled);
            verify(control.Accessible.name.length > 0);
            verify(control.mapToItem(card, control.width, 0).x <= card.width - card.contentPadding);
        }
        state.policy.same_profile = true;
        state.policy.battery.sleep_minutes = 0;
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        verify(waitForRendering(panel));
        verify(findChild(panel, "suspendDelay-plugged") === null);
        compare(findChild(panel, "suspendDelay-battery").value, "0");
        verify(!findChild(panel, "hibernateDelay-battery").enabled);
        state.policy.lid_action = "profile";
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        compare(lid.value, "profile");
        verify(findChild(panel, "hibernateDelay-battery").enabled, "lid profile works with Never idle suspend");
        state.lid.error = "Lid action failed: lock was not confirmed";
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        compare(findChild(panel, "lidCloseStatus").text, state.lid.error);
        state.policy.battery.sleep_minutes = 15;
        state.hibernate_available = false;
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        const hibernate = findChild(panel, "hibernateDelay-battery");
        verify(hibernate.options.every(function (option) {
            return option.enabled === (option.value === "0");
        }));
        state.available = false;
        panel.controller.applySuspendPolicy(JSON.parse(JSON.stringify(state)));
        verify(!findChild(panel, "suspendDelay-battery").enabled);
        verify(!findChild(panel, "suspendSameProfile").interactive);
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

    function test_keyboardNavigationAndEscapeRemainAvailable() {
        const panel = makePanel();
        panel.controller.backend.active = false;
        panel.controller.uiActive = true;
        const closeSpy = createTemporaryObject(closeSpyComponent, testCase, {
            target: panel.controller
        });
        findChild(panel, "suspendAction-lock").forceActiveFocus();
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(panel.controller.viewTab, "overview");
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 1, "Escape dismisses the battery panel directly");
    }
}
