pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../launcher" as Apps
import "../../launcher/AppApi.js" as Api

DaemonTestCase {
    id: tests
    name: "ApplicationContract"
    when: windowShown

    Component { id: factory; Apps.ApplicationController {} }

    function fixture(file) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/" + file), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function lastCall(method) {
        const matching = calls.filter(call => call.method === method);
        verify(matching.length > 0, "Missing " + method);
        return matching[matching.length - 1];
    }
    function deliver(call, envelope) {
        Io.DaemonSessions.sessions["app-daemon"].client.response(call.id, envelope, "", call.route);
    }
    function event(call, envelope) {
        const route = Object.assign({}, call.route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["app-daemon"].client.eventReceived(envelope, route);
    }
    function make() {
        calls = [];
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        controller.activateUi("1");
        deliver(lastCall(Api.methods.query), fixture("app-replies.json")[Api.methods.query]);
        compare(controller.catalogRevision, 41);
        compare(controller.filteredResults.length, 1);
        controller.select(0);
        compare(controller.selectedResult.id, "Alpha");
        return controller;
    }
    function test_queryRefreshAndRevisionReplies() {
        const controller = make();
        const replies = fixture("app-replies.json");
        const before = calls.length;
        controller.activateUi("1");
        deliver(lastCall(Api.methods.revision), replies[Api.methods.revision]);
        compare(calls.length, before + 1, "An unchanged revision must not trigger a query");
        compare(controller.revisionRequestId, "");
        controller.refresh(true);
        deliver(lastCall(Api.methods.refresh), replies[Api.methods.refresh]);
        compare(controller.catalogRevision, 41);
        compare(controller.selectedApplication.name, "Alpha");
        compare(controller.selectedApplication.default_workspace_id, "1");
        verify(!controller.refreshInFlight);
    }
    function test_settingsAndHistoryReplies() {
        const controller = make();
        const replies = fixture("app-replies.json");
        verify(controller.updateApplicationSettings("code"));
        verify(controller.settingsInFlight);
        deliver(lastCall(Api.methods.settingsUpdate), replies[Api.methods.settingsUpdate]);
        verify(!controller.settingsInFlight);
        compare(controller.status, "Saved settings for Alpha");

        controller.detailsOpen = true;
        wait(0); // Let keyed view-memory restoration finish before choosing the tab.
        controller.detailsTab = "resources";
        controller.requestResourceHistory(true);
        tryVerify(() => calls.some(call => call.method === Api.methods.history));
        const history = replies[Api.methods.history];
        // Align the pending request with the fixture's fixed clock window; the
        // production reply itself is delivered untouched through session routing.
        controller.historyWindowStartMs = history.data.history.summary.window_start_ms;
        controller.historyWindowEndMs = history.data.history.summary.window_end_ms;
        deliver(lastCall(Api.methods.history), history);
        verify(!controller.historyInFlight);
        verify(controller.resourceHistorySummary !== null);
        compare(controller.resourceHistorySummary.revision, "history-example");
    }
    function test_stateEvents_data() {
        return [{tag: "applications", stream: Api.streams.applications}, {tag: "windows", stream: Api.streams.windows}];
    }
    function test_stateEvents(data) {
        const controller = make();
        const events = fixture("app-events.json");
        const query = lastCall(Api.methods.query);
        const before = calls.length;
        for (const stream of [Api.streams.applications, Api.streams.windows, Api.streams.operation])
            event(query, events[stream + ".subscribed"]);
        wait(180);
        compare(calls.length, before, "Subscription acknowledgements do not invalidate results");
        event(query, events[data.stream]);
        tryVerify(() => calls.length === before + 1);
        compare(lastCall(Api.methods.query).method, Api.methods.query);
        deliver(lastCall(Api.methods.query), fixture("app-replies.json")[Api.methods.query]);
        compare(controller.catalogError, "");
    }
    function test_structuredErrors_data() {
        return ["daemon-unavailable", "validation-error"].map(code => ({tag: code, code: code}));
    }
    function test_structuredErrors(data) {
        const controller = make();
        controller.refresh(false);
        const error = fixture("app-replies.json").errors[data.code];
        deliver(lastCall(Api.methods.query), error);
        compare(controller.catalogError, error.error.message);
        verify(!controller.refreshInFlight);
        compare(controller.filteredResults.length, 0);
        controller.refresh(false);
        deliver(lastCall(Api.methods.query), fixture("app-replies.json")[Api.methods.query]);
        compare(controller.catalogError, "");
        compare(controller.filteredResults.length, 1);
    }
}
