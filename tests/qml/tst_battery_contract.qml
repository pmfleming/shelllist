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
}
