pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Battery as Battery

DaemonTestCase {
    id: tests
    name: "SleepContract"
    when: windowShown
    property var loadedFixture: null
    Component { id: factory; Battery.BatteryController { uiActive: true } }

    function fixture() {
        if (!loadedFixture) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-sleep.json"), false);
            request.send();
            loadedFixture = JSON.parse(request.responseText);
        }
        return loadedFixture;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function requests(controller) {
        return calls.filter(call => call.route.consumerId === controller.backend.sharedConsumerId);
    }
    function effects(controller) { return requests(controller).filter(call => call.method.startsWith("powerSleep.")); }
    function lastCall(controller, method) {
        const found = requests(controller).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method);
        return found[found.length - 1];
    }
    function reply(call, value) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(value), "", call.route);
    }
    function event(controller, value) {
        const route = Object.assign({}, lastCall(controller, "bar.snapshot").route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(value), route);
    }
    function make() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        reply(lastCall(controller, "bar.snapshot"), fixture().snapshot);
        verify(controller.powerSuspend.available);
        return controller;
    }
    function prepare(controller, method) {
        if (method === "powerSleep.cancelCritical")
            event(controller, fixture().critical.countdown);
    }
    function start(controller, method) {
        const params = clone(fixture().replies[method].params);
        let sent = false;
        switch (method) {
        case "powerSleep.lock": case "powerSleep.suspend": case "powerSleep.hibernate":
            sent = controller.powerSuspendAction(method.split(".")[1]); break;
        case "powerSleep.setKeepAwake": sent = controller.setKeepAwake(params.enabled); break;
        case "powerSleep.cancelCritical": sent = controller.cancelCriticalBattery(); break;
        case "powerSleep.setPolicy":
            controller.suspendPolicyDraft = params;
            controller.suspendPolicyDirty = true;
            sent = controller.saveSuspendPolicy(); break;
        case "powerSleep.setCriticalPolicy":
            controller.suspendPolicyDraft = Object.assign({}, controller.suspendPolicyDraft, {critical_battery: params});
            controller.suspendPolicyCriticalOnly = true;
            controller.suspendPolicyDirty = true;
            sent = controller.saveSuspendPolicy(); break;
        }
        verify(sent, method);
        const call = lastCall(controller, method);
        compare(call.params, fixture().replies[method].params);
        verify(controller.backend.isPending(call.route.localId));
        return call;
    }
    function test_replies_data() {
        // Lifecycle/cancellation tests cover action success; retain separate error owners.
        return [["powerSleep.setPolicy", "failed"], ["powerSleep.hibernate", "uncertain"]]
            .map(([method, outcome]) => ({tag: method + "/" + outcome, method: method, outcome: outcome}));
    }
    function test_replies(data) {
        const controller = make();
        prepare(controller, data.method);
        const policy = ["powerSleep.setPolicy", "powerSleep.setCriticalPolicy", "powerSleep.cancelCritical"].includes(data.method);
        const property = policy ? "suspendPolicyState" : "powerSuspend";
        const before = JSON.stringify(controller[property]);
        const call = start(controller, data.method);
        compare(JSON.stringify(controller[property]), before, "Sending is not acknowledgement");
        const response = fixture().replies[data.method][data.outcome];
        reply(call, response);
        verify(!controller.backend.isPending(call.route.localId));
        verify(!controller.actionInFlight);
        verify(!controller.keepAwakePending);
        verify(!controller.suspendPolicySaving);
        compare(controller.suspendPendingAction, "");
        if (response.ok) {
            compare(controller[property], response.data[policy ? "sleep_policy" : "power_sleep"]);
            if (["powerSleep.suspend", "powerSleep.hibernate", "powerSleep.idle"].includes(data.method)) {
                verify(controller.suspendBusy, "Acknowledgement is not completed sleep");
                compare(controller.powerSuspend.operation.phase, "accepted");
                verify(controller.suspendStatus.includes("awaiting system confirmation"));
            }
            if (["powerSleep.setPolicy", "powerSleep.setCriticalPolicy"].includes(data.method)) {
                verify(!controller.suspendPolicyDirty);
                compare(controller.suspendPolicyDraft, response.data.sleep_policy.policy, "Use authoritative settings, including retained critical policy");
            }
        } else {
            compare(JSON.stringify(controller[property]), before, "A rejected reply cannot replace acknowledged state");
            const error = data.method === "powerSleep.setKeepAwake" ? controller.keepAwakeError
                : data.method === "powerSleep.cancelCritical" ? controller.lastError
                : policy ? controller.suspendPolicyError : controller.suspendError;
            compare(error, response.error.message);
        }
        compare(effects(controller).length, 1);
    }
    function test_lifecycle_data() { return [{tag: "suspend", action: "suspend"}]; }
    function test_lifecycle(data) {
        const controller = make();
        const call = start(controller, "powerSleep." + data.action);
        const events = fixture().events[data.action];
        for (const phase of ["requested", "dispatching"]) {
            event(controller, events[phase]);
            verify(controller.actionInFlight);
            verify(!controller.canPowerSuspendAction(data.action));
        }
        reply(call, fixture().replies[call.method].success);
        verify(!controller.actionInFlight);
        verify(controller.suspendBusy);
        for (const phase of ["preparing", "returned"]) {
            event(controller, events[phase]);
            compare(controller.powerSuspend, events[phase].data);
            verify(controller.suspendBusy);
            verify(!controller.powerSuspendAction(data.action), "No duplicate sleep while a correlated job is pending");
        }
        event(controller, events.completed);
        compare(controller.powerSuspend.operation.phase, "completed");
        compare(controller.powerSuspend.resume_generation, 1);
        verify(!controller.suspendBusy);
        verify(controller.canPowerSuspendAction(data.action));
        compare(effects(controller).length, 1);
    }
    function test_terminalOutcomes_data() {
        // Failed versus unknown execution, not every daemon diagnostic label.
        return [["hibernate", "interrupted-dispatch"]]
            .map(([action, outcome]) => ({tag: action + "/" + outcome, action: action, outcome: outcome}));
    }
    function test_terminalOutcomes(data) {
        const controller = make();
        const value = fixture().events[data.action][data.outcome];
        event(controller, value);
        compare(controller.powerSuspend, value.data);
        const unknown = value.data.operation.phase === "unknown";
        compare(controller.suspendOutcomeUnknown, unknown);
        verify(!controller.suspendBusy);
        verify(controller.suspendStatus.includes(unknown ? "outcome unknown" : "failed"));
        verify(controller.powerSuspend.operation.error.length > 0);
        wait(0);
        compare(effects(controller).length, 0, "Failure, worker cancellation and uncertainty cannot initiate a retry");
    }
    function test_reconnectNeverReplays_data() {
        return [["suspend", "pending"]]
            .map(([action, stage]) => ({tag: action + "/" + stage, action: action, stage: stage}));
    }
    function test_reconnectNeverReplays(data) {
        const controller = make();
        const call = start(controller, "powerSleep." + data.action);
        if (data.stage !== "pending")
            reply(call, fixture().replies[call.method].success);
        if (data.stage === "unknown")
            event(controller, fixture().events[data.action]["reply-lost"]);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Connection interrupted");
        verify(!controller.backend.isPending(call.route.localId));
        verify(!controller.actionInFlight);
        compare(controller.suspendPendingAction, "");
        if (data.stage === "pending")
            verify(controller.suspendError.includes("may already have been accepted"));
        const readCount = requests(controller).filter(call => call.method === "bar.snapshot").length;
        clientReady = true;
        compare(requests(controller).filter(call => call.method === "bar.snapshot").length, readCount + 1);
        reply(lastCall(controller, "bar.snapshot"), fixture().recovery[data.action]);
        verify(controller.suspendOutcomeUnknown);
        verify(controller.suspendStatus.includes("outcome unknown"));
        wait(0);
        compare(effects(controller).length, 1, "Recovery may read state, never replay suspend or hibernate");
    }
    function test_criticalCancellationDoesNotUndoDispatchedSleep() {
        const controller = make();
        event(controller, fixture().events.hibernate.accepted);
        prepare(controller, "powerSleep.cancelCritical");
        const call = start(controller, "powerSleep.cancelCritical");
        reply(call, fixture().replies[call.method].success);
        compare(controller.suspendPolicyState.critical_battery.phase, "cancelled");
        verify(controller.suspendPolicyState.critical_battery.error.includes("cannot be undone"));
        event(controller, fixture().critical.cancelled);
        compare(controller.powerSuspend.operation.phase, "accepted");
        verify(controller.suspendBusy, "Countdown cancellation is not systemd job cancellation");
        event(controller, fixture().events.hibernate.completed);
        compare(controller.powerSuspend.operation.phase, "completed");
        compare(effects(controller).length, 1);
    }
}
