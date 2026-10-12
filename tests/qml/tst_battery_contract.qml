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
    function effects(c) { return requests(c).filter(call => Object.keys(fixture().cases).includes(call.method)); }
    function lastCall(c, method) {
        const found = requests(c).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(envelope), error || "", call.route);
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
        const call = lastCall(c, method); compare(call.params, params);
        verify(c.backend.isPending(call.route.localId)); return call;
    }
    function test_outcomes_data() {
        const rows = [];
        for (const method of Object.keys(fixture().cases))
            for (const outcome of ["success", "limited", "failed", "rejected", "readbackFailed"])
                if (fixture().cases[method][outcome]) rows.push({tag:method + "/" + outcome, method:method, outcome:outcome});
        return rows;
    }
    function test_outcomes(data) {
        const c = make(data.method); const before = JSON.stringify(c.battery);
        const call = start(c, data.method);
        compare(JSON.stringify(c.battery), before);
        const response = fixture().cases[data.method][data.outcome];
        reply(call, response);
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
        const rows = [];
        for (const method of Object.keys(fixture().cases))
            for (const disconnect of [false, true]) rows.push({tag:method + (disconnect ? "/disconnect" : "/timeout"), method:method, disconnect:disconnect});
        return rows;
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
        const rows = [];
        for (const method of ["battery.setThresholds", "battery.setAlertPolicy"])
            for (const timeout of [false, true]) rows.push({tag:method + (timeout ? "/timeout" : "/ack"), method:method, timeout:timeout});
        return rows;
    }
    function test_newerDraft(data) {
        const c = make(data.method); const call = start(c, data.method);
        const threshold = data.method === "battery.setThresholds";
        if (threshold) c.updateStartPercent(65, false);
        else c.updateWarningPercent(35, false);
        if (data.timeout) reply(call, null, "Outcome unknown");
        else reply(call, fixture().cases[data.method].success);
        wait(650);
        compare(effects(c).length, 2, "A genuinely newer edit remains a new user request");
        const newer = lastCall(c, data.method);
        compare(newer.params[threshold ? "start_percent" : "warning_percent"], threshold ? 65 : 35);
        compare(threshold ? c.draftStartPercent : c.alertDraft.warning_percent, threshold ? 65 : 35);
        verify(threshold ? c.thresholdDraftDirty : c.alertDraftDirty);
    }
    function test_calibrationRestoration() {
        const c = make("battery.startCalibration");
        const call = start(c, "battery.startCalibration");
        reply(call, fixture().cases[call.method].success);
        verify(c.calibrating); verify(!c.actionInFlight);
        event(c, fixture().events.charging); compare(c.batteryOperation.phase, "charging");
        const cancel = start(c, "battery.cancelCalibration");
        event(c, fixture().events.restoring);
        reply(cancel, fixture().restorationFailed);
        verify(c.calibrating, "Failed restoration is still a durable operation");
        compare(c.batteryOperation.phase, "restoring");
        verify(!c.chargeOnce());
        event(c, fixture().events.completed);
        verify(!c.calibrating); verify(!c.batteryOperationActive);
        compare(effects(c).length, 2);
    }
}
