pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Battery as Battery

DaemonTestCase {
    id: tests
    name: "BatteryContract"
    when: windowShown
    property var loaded: null
    Component { id: factory; Battery.BatteryController { uiActive: true } }
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-battery.json"), false);
            request.send(); loaded = JSON.parse(request.responseText);
        }
        return loaded;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() { calls = []; clientReady = true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function requests(c) { return calls.filter(call => call.route.consumerId === c.backend.sharedConsumerId); }
    function effects(c) { return requests(c).filter(call => call.method === "battery.operation.start" || Object.keys(fixture().cases).includes(call.method)); }
    function lastCall(c, method) {
        const found = requests(c).filter(call => call.method === method || (call.method === "battery.operation.start" && call.params.method === method));
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(envelope), error || "", call.route);
    }
    function complete(c, call, method, outcome) {
        if (call.method !== "battery.operation.start") {
            reply(call, fixture().cases[method][outcome]);
            return;
        }
        reply(call, fixture().operationStarted);
        verify(c.actionInFlight || c.settingsOperationActive, "Acknowledgement is not completion");
        c.backend.interactiveOperations.poll();
        reply(lastCall(c, "battery.operation.status"), outcome === "restorationFailed" ? fixture().operationRestorationFailed : fixture().operationFinished[method][outcome]);
    }
    function event(c, value) {
        const route = Object.assign({}, lastCall(c, "bar.snapshot").route, {kind:"base-subscription", localId:"session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(value), route);
    }
    function make(method) {
        const c = createTemporaryObject(factory, tests); verify(c !== null);
        reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        reply(lastCall(c, "battery.history"), fixture().history);
        compare(c.batteryHistory, fixture().history.data.history);
        if (method === "battery.cancelCalibration") event(c, fixture().events.discharging);
        return c;
    }
    function start(c, method) {
        const params = clone(fixture().cases[method].params);
        let sent = false;
        switch (method) {
        case "battery.setThresholds": case "battery.setProtection":
            c.updateStartPercent(params.start_percent, false);
            if (method === "battery.setProtection") c.protectionRevision += 1;
            sent = c.flushThresholdPolicy(); break;
        case "battery.chargeOnce": sent = c.chargeOnce(); break;
        case "battery.setChargingInhibited": sent = c.setChargingInhibited(params.enabled); break;
        case "battery.startCalibration": case "battery.cancelCalibration": sent = c.toggleCalibration(); break;
        case "battery.setAlertPolicy":
            c.alertDraft = params; c.markAlertChanged(false);
            sent = c.flushAlertPolicy(); break;
        }
        verify(sent, method);
        const call = lastCall(c, method); compare(call.method === "battery.operation.start" ? call.params.params : call.params, params);
        verify(c.backend.isPending(call.route.localId)); return call;
    }
    function test_outcomes_data() {
        // Limited readbacks exercise acknowledgement plus unverified hardware state.
        // Draft and calibration workflows below retain normal completion coverage.
        return [["battery.chargeOnce", "limited"], ["battery.setProtection", "limited"],
                ["battery.setAlertPolicy", "failed"],
                ["battery.setChargingInhibited", "rejected"], ["battery.startCalibration", "readbackFailed"]]
            .map(([method, outcome]) => ({tag: method + "/" + outcome, method: method, outcome: outcome}));
    }
    function test_outcomes(data) {
        const c = make(data.method); const before = JSON.stringify(c.battery);
        const call = start(c, data.method);
        compare(JSON.stringify(c.battery), before);
        const response = fixture().cases[data.method][data.outcome];
        complete(c, call, data.method, data.outcome);
        verify(!c.backend.isPending(call.route.localId)); verify(!c.actionInFlight); verify(!c.settingsOperationActive);
        if (response.ok) {
            compare(c.battery, response.data.battery);
            compare(c.lastError, "");
            if (data.outcome === "limited") {
                compare(c.protection.start_percent, response.data.operation.start_percent);
                compare(c.protection.end_percent, response.data.operation.end_percent);
                verify(!response.data.operation.verified);
            }
        } else {
            compare(c.lastError, response.error.message);
            compare(JSON.stringify(c.battery), before);
        }
        compare(effects(c).length, 1);
    }
    function test_noReplay_data() {
        return [["battery.setThresholds", false]]
            .map(([method, disconnect]) => ({tag: method + (disconnect ? "/disconnect" : "/timeout"), method: method, disconnect: disconnect}));
    }
    function test_noReplay(data) {
        const c = make(data.method); const call = start(c, data.method);
        if (data.disconnect) {
            clientReady = false;
            Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Outcome unknown");
            clientReady = true;
            reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        } else reply(call, null, "Outcome unknown");
        wait(650); // Beyond both settings debounce timers, not just the next event loop.
        compare(effects(c).length, 1, "No automatic replay after uncertain execution");
        verify(!c.backend.isPending(call.route.localId));
        if (["battery.setThresholds", "battery.setProtection"].includes(data.method)) {
            verify(c.thresholdDraftDirty); compare(c.draftStartPercent, 60);
            verify(c.flushThresholdPolicy(), "Explicit user retry remains possible");
            compare(effects(c).length, 2);
        } else if (data.method === "battery.setAlertPolicy") {
            verify(c.alertDraftDirty); compare(c.alertDraft.warning_percent, 30);
            verify(c.flushAlertPolicy()); compare(effects(c).length, 2);
        }
    }
    function test_newerDraft_data() {
        return [
            {tag:"battery.setThresholds/ack", method:"battery.setThresholds", timeout:false},
            {tag:"battery.setAlertPolicy/timeout", method:"battery.setAlertPolicy", timeout:true}
        ];
    }
    function test_newerDraft(data) {
        const c = make(data.method); const call = start(c, data.method);
        const threshold = data.method === "battery.setThresholds";
        if (threshold) c.updateStartPercent(65, false);
        else c.updateWarningPercent(35, false);
        if (data.timeout) reply(call, null, "Outcome unknown");
        else complete(c, call, data.method, "success");
        wait(650);
        compare(effects(c).length, 2, "A genuinely newer edit remains a new user request");
        const newer = lastCall(c, data.method);
        const params = newer.method === "battery.operation.start" ? newer.params.params : newer.params;
        compare(params[threshold ? "start_percent" : "warning_percent"], threshold ? 65 : 35);
        compare(threshold ? c.draftStartPercent : c.alertDraft.warning_percent, threshold ? 65 : 35);
        verify(threshold ? c.thresholdDraftDirty : c.alertDraftDirty);
    }
    function test_terminalStatusCannotOverwriteNewerBatteryPush() {
        const c = make("battery.chargeOnce");
        reply(start(c, "battery.chargeOnce"), fixture().operationStarted);
        event(c, fixture().events.charging);
        const current = JSON.stringify(c.battery);
        c.backend.interactiveOperations.poll();
        reply(lastCall(c, "battery.operation.status"), fixture().operationFinished["battery.chargeOnce"].success);
        compare(JSON.stringify(c.battery), current);
        verify(!c.actionInFlight, "Stale state is discarded, not the operation acknowledgement");
        compare(effects(c).length, 1);
        verify(!Object.keys(c.backend.requestPolicy.responseEpochs).some(id => id.startsWith("battery-operation-result::")));
    }
    function test_cancelAcknowledgesIntentNotRollback() {
        const c = make("battery.chargeOnce");
        const call = start(c, "battery.chargeOnce");
        reply(call, fixture().operationStarted);
        verify(c.actionInFlight);
        c.backend.interactiveOperations.cancel();
        reply(lastCall(c, "battery.operation.cancel"), fixture().operationCancelled);
        verify(c.actionInFlight, "Cancel intent is not proof that a write stopped");
        c.backend.interactiveOperations.poll();
        reply(lastCall(c, "battery.operation.status"), fixture().operationUnknown);
        verify(!c.actionInFlight);
        verify(c.lastError.includes("unknown"));
        compare(effects(c).length, 1);
    }
    function test_statusTimeoutDoesNotReplayStart() {
        const c = make("battery.chargeOnce");
        reply(start(c, "battery.chargeOnce"), fixture().operationStarted);
        c.backend.interactiveOperations.poll();
        reply(lastCall(c, "battery.operation.status"), null, "Outcome unknown");
        verify(!c.actionInFlight);
        wait(1100);
        compare(effects(c).length, 1);
        compare(Object.keys(c.backend.interactiveOperations.requests).length, 0);
    }
    function test_ownerLossAfterAcknowledgementDoesNotClaimOldStatus() {
        const c = make("battery.chargeOnce");
        reply(start(c, "battery.chargeOnce"), fixture().operationStarted);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Owner lost");
        clientReady = true;
        c.backend.interactiveOperations.poll();
        compare(Object.keys(c.backend.interactiveOperations.requests).length, 0);
        compare(requests(c).filter(call => call.method === "battery.operation.status").length, 0);
        compare(effects(c).length, 1);
        verify(!c.actionInFlight);
    }
    function test_calibrationRestoration() {
        const c = make("battery.startCalibration");
        const call = start(c, "battery.startCalibration");
        complete(c, call, "battery.startCalibration", "success");
        verify(c.calibrating); verify(!c.actionInFlight);
        event(c, fixture().events.charging); compare(c.batteryOperation.phase, "charging");
        const cancel = start(c, "battery.cancelCalibration");
        event(c, fixture().events.restoring);
        complete(c, cancel, "battery.cancelCalibration", "restorationFailed");
        verify(c.calibrating, "Failed restoration is still a durable operation");
        compare(c.batteryOperation.phase, "restoring");
        verify(!c.chargeOnce());
        event(c, fixture().events.completed);
        verify(!c.calibrating); verify(!c.batteryOperationActive);
        compare(effects(c).length, 2);
    }
}
