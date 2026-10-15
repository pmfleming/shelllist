pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "ActivityContract"
    when: windowShown
    property var loaded: null
    Component { id: factory; Activity.ActivityController { uiActive: true; rangeQueriesEnabled: false; selectedDate: new Date(2026, 0, 15) } }
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-activity.json"), false);
            request.send(); loaded = JSON.parse(request.responseText);
        }
        return loaded;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() { calls = []; clientReady = true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function requests(c) { return calls.filter(call => call.route.consumerId === c.backend.sharedConsumerId); }
    function effects(c) { return requests(c).filter(call => call.method.startsWith("todos.") || call.method === "activity.refresh"); }
    function lastCall(c, method) {
        const found = requests(c).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) { Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(envelope), error || "", call.route); }
    function event(c, value) {
        const route = Object.assign({}, lastCall(c, "bar.snapshot").route, {kind:"base-subscription", localId:"session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(value), route);
    }
    function make() {
        const c = createTemporaryObject(factory, tests); verify(c !== null);
        reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        reply(start(c, "range"), fixture().cases.range.success);
        return c;
    }
    function start(c, key) {
        const example = fixture().cases[key]; const params = example.params;
        let sent = false;
        switch (key) {
        case "range": case "emptyRange": sent = c.backend.queryRange(new Date(params.from_unix_ms), new Date(params.to_unix_ms)); break;
        case "create": sent = c.createTodo(params.title); break;
        case "complete": sent = c.toggleTodo(fixture().cases.create.success.data.todo); break;
        case "reopen": sent = c.toggleTodo(fixture().cases.complete.success.data.todo); break;
        case "delete": sent = c.deleteTodo(fixture().cases.create.success.data.todo); break;
        case "refresh": sent = c.backend.refresh(); break;
        }
        verify(sent, key);
        const call = lastCall(c, example.method); compare(call.params, params);
        verify(c.backend.isPending(call.route.localId)); return call;
    }
    function test_outcomes_data() {
        return [["range", "failed"]]
            .map(([key, outcome]) => ({tag: key + "/" + outcome, key: key, outcome: outcome}));
    }
    function test_outcomes(data) {
        const c = make(); const before = clone(c.todos);
        const call = start(c, data.key); compare(c.todos, before);
        const response = fixture().cases[data.key][data.outcome]; reply(call, response);
        verify(!c.backend.isPending(call.route.localId));
        if (response.ok) {
            compare(c.lastError, "");
            if (response.data.activity_range) {
                const range = response.data.activity_range;
                compare(c.todos, range.todos); compare(c.events, range.events); compare(c.days, range.days); compare(c.busyDates, range.busy_dates);
                compare(c.loadedFrom.getTime(), range.from_unix_ms); compare(c.loadedTo.getTime(), range.to_unix_ms);
            } else {
                compare(c.todos, before, "Todo acknowledgement is not an authoritative range replacement");
                if (data.key === "refresh") { verify(c.activity.syncing); event(c, fixture().events.completed); verify(!c.activity.syncing); }
            }
        } else { compare(c.lastError, response.error.message); compare(c.todos, before); }
    }
    function test_noReplay_data() {
        return [["delete", true]]
            .map(([key, disconnect]) => ({tag: key + (disconnect ? "/disconnect" : "/timeout"), key: key, disconnect: disconnect}));
    }
    function test_noReplay(data) {
        const c = make(); const call = start(c, data.key);
        if (data.disconnect) {
            clientReady = false; Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Outcome unknown"); clientReady = true;
            reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        } else reply(call, null, "Outcome unknown");
        wait(160); compare(effects(c).length, 1);
        verify(!c.backend.isPending(call.route.localId));
        // Reconcile by reading, never by repeating create/complete/delete.
        reply(start(c, "range"), fixture().cases.range.success);
        compare(effects(c).length, 1); compare(c.todos, fixture().cases.range.success.data.activity_range.todos);
    }
    function test_lateRangeCannotReplaceNewerRange_data() { return [{tag:"old-success", failed:false}]; }
    function test_lateRangeCannotReplaceNewerRange(data) {
        const c = make(); const old = start(c, "range"); const current = start(c, "emptyRange");
        reply(current, fixture().cases.emptyRange.success);
        reply(old, fixture().cases.range[data.failed ? "failed" : "success"]);
        compare(c.todos.length, 0); compare(c.lastError, "");
        compare(c.loadedFrom.getTime(), fixture().cases.emptyRange.params.from_unix_ms);
    }
}
