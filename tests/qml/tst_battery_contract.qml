pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Battery as Battery

DaemonTestCase {
    id: tests
    name: "BatteryContract"
    when: windowShown
    readonly property var contractFixture: readFixture("bar-battery")
    Component { id: factory; Battery.BatteryController { uiActive: true } }
    function init() { calls = []; clientReady = true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function requests(c) { return calls.filter(call => call.route.consumerId === c.backend.sharedConsumerId); }
    function effects(c) { return requests(c).filter(call => call.method === "battery.operation.start" || Object.keys(contractFixture.cases).includes(call.method)); }
    function lastCall(c, method) {
        const found = requests(c).filter(call => call.method === method || (call.method === "battery.operation.start" && call.params.method === method));
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) {
        Io.DaemonSessions.sessions["power-daemon"].client.response(call.id, clone(envelope), error || "", call.route);
    }
    function event(c, value) {
        const route = Object.assign({}, lastCall(c, "bar.snapshot").route, {kind:"base-subscription", localId:"session-subscribe"});
        emitBaseEvent("power-daemon", route, clone(value));
    }
    function make(method) {
        const c = createTemporaryObject(factory, tests); verify(c !== null);
        reply(lastCall(c, "bar.snapshot"), contractFixture.snapshot);
        reply(lastCall(c, "battery.history"), contractFixture.history);
        compare(c.batteryHistory, contractFixture.history.data.history);
        if (method === "battery.cancelCalibration") event(c, contractFixture.events.discharging);
        return c;
    }
    function start(c, method) {
        const params = clone(contractFixture.cases[method].params);
        let sent = false;
        switch (method) {
        case "battery.setThresholds": case "battery.setProtection":
            c.settings.updateStartPercent(params.start_percent, false);
            if (method === "battery.setProtection") c.settings.protectionRevision += 1;
            sent = c.settings.flushThresholdPolicy(); break;
        case "battery.chargeOnce": sent = c.chargeOnce(); break;
        case "battery.setChargingInhibited": sent = c.setChargingInhibited(params.enabled); break;
        case "battery.startCalibration": case "battery.cancelCalibration": sent = c.toggleCalibration(); break;
        case "battery.setAlertPolicy":
            c.settings.alertDraft = params; c.settings.markAlertChanged(false);
            sent = c.settings.flushAlertPolicy(); break;
        }
        verify(sent, method);
        const call = lastCall(c, method); compare(call.method === "battery.operation.start" ? call.params.params : call.params, params);
        verify(c.backend.isPending(call.route.localId)); return call;
    }
    function test_lateHistoryRangeCannotReplaceTheLatestNativeChart() {
        const c = make("battery.setThresholds");
        c.requestHistory(24);
        const older = lastCall(c, "battery.history");
        c.requestHistory(168);
        const newer = lastCall(c, "battery.history");
        compare(older.params, {hours:24});
        compare(newer.params, {hours:168});
        reply(newer, contractFixture.windows["168"]);
        compare(c.batteryHistory, contractFixture.windows["168"].data.history);
        reply(older, contractFixture.windows["24"]);
        compare(c.batteryHistory, contractFixture.windows["168"].data.history);
        compare(c.historyHours, 168);
        compare(effects(c).length, 0);
    }
    function test_noReplay_data() {
        return [["battery.setThresholds", false], ["battery.setThresholds", true],
            ["battery.setAlertPolicy", false], ["battery.setAlertPolicy", true]]
            .map(([method, disconnect]) => ({tag: method + (disconnect ? "/disconnect" : "/timeout"), method: method, disconnect: disconnect}));
    }
    function test_noReplay(data) {
        const c = make(data.method); const call = start(c, data.method);
        if (data.disconnect) {
            clientReady = false;
            Io.DaemonSessions.sessions["power-daemon"].client.transportFailed("Outcome unknown");
            clientReady = true;
            reply(lastCall(c, "bar.snapshot"), contractFixture.snapshot);
        } else reply(call, null, "Outcome unknown");
        wait(650); // Beyond both settings debounce timers, not just the next event loop.
        compare(effects(c).length, 1, "No automatic replay after uncertain execution");
        verify(!c.backend.isPending(call.route.localId));
        if (["battery.setThresholds", "battery.setProtection"].includes(data.method)) {
            verify(c.settings.thresholdDraftDirty); compare(c.settings.draftStartPercent, 60);
            verify(c.settings.flushThresholdPolicy(), "Explicit user retry remains possible");
            compare(effects(c).length, 2);
        } else if (data.method === "battery.setAlertPolicy") {
            verify(c.settings.alertDraftDirty); compare(c.settings.alertDraft.warning_percent, 30);
            verify(c.settings.flushAlertPolicy()); compare(effects(c).length, 2);
        }
    }
    function test_thresholdCompletionPreservesANewerSavedRevision() {
        const c = make("battery.setThresholds");
        const first = start(c, "battery.setThresholds");
        c.settings.updateEndPercent(85, false);
        const completion = clone(contractFixture.operationFinished["battery.setThresholds"].success);
        reply(first, completion);
        verify(c.settings.thresholdDraftDirty);
        compare(c.settings.draftEndPercent, 85, "acknowledging an older save cannot overwrite the next saved revision");
        tryVerify(() => effects(c).length === 2);
        const next = lastCall(c, "battery.setThresholds");
        compare(next.params.params, {battery_id: "BAT0", start_percent: 60, end_percent: 85});
        reply(first, completion);
        verify(c.settings.thresholdOperationActive, "a duplicate old reply cannot retire the new operation");
    }
    function test_domainRecoveryAndSubscriptionRenewalKeepAcceptedBatteryWork() {
        const c = make("battery.chargeOnce");
        const call = start(c, "battery.chargeOnce");
        reply(call, contractFixture.operationStarted);
        const pending = JSON.stringify(c.backend.interactiveOperations.requests);
        c.backend.requestPolicy.recover("battery.changed");
        const read = lastCall(c, "bar.snapshot");
        compare(read.params.streams, ["battery.changed"]);
        reply(read, contractFixture.snapshot);
        verify(c.actionInFlight);
        compare(JSON.stringify(c.backend.interactiveOperations.requests), pending);
        verify(c.backend.renewBaseSubscription());
        event(c, {protocol: "bar-api", version: 2, stream: "battery.changed", event: "subscribed", data: contractFixture.snapshot.data.snapshot.battery});
        verify(c.actionInFlight);
        compare(JSON.stringify(c.backend.interactiveOperations.requests), pending);
        compare(effects(c).length, 1, "renewal cannot cancel or replay accepted work");
    }
    function test_cancelAcknowledgesIntentNotRollback() {
        const c = make("battery.chargeOnce");
        const call = start(c, "battery.chargeOnce");
        reply(call, contractFixture.operationStarted);
        verify(c.actionInFlight);
        c.backend.interactiveOperations.cancel();
        reply(lastCall(c, "battery.operation.cancel"), contractFixture.operationCancelled);
        verify(c.actionInFlight, "Cancel intent is not proof that a write stopped");
        c.backend.interactiveOperations.poll();
        reply(lastCall(c, "battery.operation.status"), contractFixture.operationUnknown);
        verify(!c.actionInFlight);
        verify(c.lastError.includes("unknown"));
        compare(effects(c).length, 1);
    }
}
