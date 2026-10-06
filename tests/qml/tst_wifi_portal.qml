pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Wifi as Wifi
import "../../wifi/process" as Process

DaemonTestCase {
    id: testCase
    name: "WifiPortal"
    when: windowShown
    visible: true
    width: 1000
    height: 760

    Component {
        id: panelFactory
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias page: page
            property alias executor: executor
            Wifi.WifiController {
                id: controller
                prompt: Wifi.WifiPromptController {}
            }
            Wifi.WifiContent {
                id: page
                anchors.fill: parent
                controller: panel.controller
            }
            QtObject {
                id: executor
                property bool running: false
                property var commands: []
                property bool failStart: false
                function exec(args) {
                    if (failStart)
                        throw new Error("cannot start");
                    commands = commands.concat([args]);
                    running = true;
                }
            }
        }
    }
    Component {
        id: commandFactory
        Process.CommandProcess {
            property int failedStarts: 0
            property int exits: 0
            onStartFailed: failedStarts++
            onFinished: exits++
        }
    }
    function test_processAdapterDetectsAsynchronousExecFailureOnce() {
        const command = createTemporaryObject(commandFactory, testCase);
        const child = findChild(command, "portalChildProcess");
        verify(child !== null);
        command.awaitingResult = true;
        child.running = true;
        child.running = false;
        compare(command.failedStarts, 1);
        child.exited(-1);
        compare(command.exits, 0, "a late exit cannot acknowledge twice");
        command.awaitingResult = true;
        child.running = true;
        child.started();
        child.running = false;
        child.exited(0);
        compare(command.failedStarts, 1);
        compare(command.exits, 1);
    }
    function makePanel() {
        const panel = createTemporaryObject(panelFactory, testCase);
        verify(panel !== null);
        panel.controller.backend.portalExecutor = panel.executor;
        calls = [];
        return panel;
    }
    function portalCalls() {
        return calls.filter(function (call) { return call.method.startsWith("network.portal"); });
    }
    function intent(id) {
        return {launch_id: id || "launch-1", episode: "daemon-opaque-episode", url: "http://probe.example/check", reason: "manual", expires_at_ms: Date.now() + 10000};
    }
    function reply(panel, data, id) {
        panel.controller.backend.acceptSharedResponse(id || panel.controller.portal.pendingId, {
            protocol: "nm-api", version: 1, ok: true, data: {portal: data}
        }, "");
    }
    function claim(panel, value) {
        reply(panel, {decision: "launch", intent: value});
        compare(portalCalls().slice(-1)[0].method, "network.portalClaim");
        compare(panel.executor.commands.length, 0, "prepare alone cannot execute");
        reply(panel, {intent: value});
    }
    function test_manualUsesClaimedUrlAndUiWorkspaceAndAcknowledges() {
        const panel = makePanel();
        verify(panel.controller.portal.launchManual("name:here", false));
        compare(portalCalls()[0].params.mode, "manual");
        compare(portalCalls()[0].params.connect_request_id, undefined);
        const value = intent();
        claim(panel, value);
        compare(panel.executor.commands.length, 1);
        compare(panel.executor.commands[0], ["shelllist-portal-launch", "--url", value.url, "--workspace", "name:here", "--expires-at-ms", String(value.expires_at_ms)]);
        panel.executor.running = false;
        panel.controller.backend.finishPortal(0, '{"outcome":"opened"}');
        compare(portalCalls()[2].method, "network.portalComplete");
        compare(portalCalls()[2].params, {launch_id: value.launch_id, outcome: "opened"});
        reply(panel, {launch_id: value.launch_id, outcome: "opened"});
        verify(!panel.controller.portal.busy);
    }
    function test_overlapAndAutomaticSuppressionNeverLaunchOrInventIdentity() {
        const panel = makePanel();
        verify(panel.controller.portal.launchForConnect("connect-42", "4"));
        compare(portalCalls()[0].params, {mode: "automatic", fallback: false, connect_request_id: "connect-42"});
        verify(!panel.controller.portal.launchManual("5", false));
        compare(portalCalls().length, 1);
        reply(panel, {decision: "suppressed", intent: null});
        verify(!panel.controller.portal.busy);
        compare(panel.executor.commands.length, 0);
    }
    function test_expiredAndChangedClaimsFailClosed_data() {
        return [{tag:"expired", expired:true}, {tag:"changed", expired:false}];
    }
    function test_expiredAndChangedClaimsFailClosed(data) {
        const panel = makePanel();
        panel.controller.portal.launchManual("1", false);
        const value = intent();
        reply(panel, {decision:"launch", intent:value});
        const changed = Object.assign({}, value);
        if (data.expired)
            changed.expires_at_ms = Date.now() - 1;
        else
            changed.launch_id = "other-launch";
        reply(panel, {intent:changed});
        compare(panel.executor.commands.length, 0);
        verify(!panel.controller.portal.busy);
    }
    function test_reconnectDropsLateRepliesAndDoesNotReplay() {
        const panel = makePanel();
        panel.controller.portal.launchForConnect("connect-1", "1");
        reply(panel, {decision:"launch", intent:intent()});
        const oldClaimId = panel.controller.portal.pendingId;
        panel.controller.backend.failSharedTransport("gone");
        panel.controller.backend.handleTransportReady();
        compare(portalCalls().length, 2, "transport recovery must not replay portal effects");
        panel.controller.portal.launchManual("2", false);
        reply(panel, {intent:intent()}, oldClaimId);
        compare(panel.executor.commands.length, 0);
        compare(panel.controller.portal.phase, "prepare");
        claim(panel, intent("new-launch"));
        compare(panel.executor.commands.length, 1);
    }
    function test_processFailureAndUncertaintyAreAcknowledgedWithoutRetry_data() {
        return [
            {tag:"known-no-effect", code:0, output:'{"outcome":"failed"}', expected:"failed"},
            {tag:"crash", code:9, output:'{"outcome":"opened"}', expected:"uncertain"}
        ];
    }
    function test_processFailureAndUncertaintyAreAcknowledgedWithoutRetry(data) {
        const panel = makePanel();
        panel.controller.portal.launchManual("1", false);
        claim(panel, intent());
        panel.executor.running = false;
        panel.controller.backend.finishPortal(data.code, data.output);
        compare(portalCalls().slice(-1)[0].params.outcome, data.expected);
        compare(panel.executor.commands.length, 1);
        reply(panel, {outcome:data.expected});
        compare(portalCalls().length, 3);
    }
    function test_startFailureAndUiDisappearanceDoNotReplay() {
        const panel = makePanel();
        panel.executor.failStart = true;
        panel.controller.portal.launchManual("1", false);
        claim(panel, intent());
        compare(portalCalls().slice(-1)[0].params.outcome, "failed");
        compare(panel.executor.commands.length, 0);
        panel.controller.backend.failSharedTransport("gone before acknowledgement");
        panel.destroy();
        wait(0);
        const reopened = makePanel();
        reopened.controller.backend.handleTransportReady();
        compare(portalCalls().length, 0);
        compare(reopened.executor.commands.length, 0);
    }
    function test_networkChangedDenialRetainsManualRetryWithoutExecuting() {
        const panel = makePanel();
        panel.controller.portal.launchForConnect("connect-1", "1");
        reply(panel, {decision:"launch", intent:intent()});
        panel.controller.backend.acceptSharedResponse(panel.controller.portal.pendingId, {
            protocol:"nm-api", version:1, ok:false,
            error:{code:"validation-error", message:"portal connection changed"}
        }, "");
        verify(!panel.controller.portal.busy);
        verify(panel.controller.status.indexOf("changed") >= 0);
        compare(panel.executor.commands.length, 0);
        verify(panel.controller.portal.launchManual("2", false));
        compare(portalCalls().slice(-1)[0].params.mode, "manual");
    }
    function test_signInUsesAltCommandNotFieldNavigation() {
        const panel = makePanel();
        panel.controller.uiActive = true;
        panel.controller.applyNetworks([{key:"cafe", ssid:"Cafe", active:true, strength:70, security:"Open", capabilities:{can_connect:true}}], true, {});
        tryVerify(function () { return panel.page.listItem !== null; });
        panel.controller.backend.pending = ({});
        panel.page.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryCompare(panel.controller, "detailsOpen", true);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Escape);
        compare(portalCalls().length, 0, "navigation never launches a portal");
        panel.controller.detailsOpen = true;
        panel.page.listItem.focusList();
        tryVerify(function () { return panel.page.detailsNavigation.commandButtons.some(function (button) { return button.accessKey === "I"; }); });
        verify(panel.page.detailsNavigation.headerShortcutsEnabled);
        keyClick(Qt.Key_I, Qt.AltModifier);
        tryCompare(panel.controller.portal, "phase", "prepare");
        compare(portalCalls().length, 1);
        compare(panel.executor.commands.length, 0, "Alt+I requests an intent, not an unacknowledged browser effect");
    }
}
