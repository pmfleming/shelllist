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
}
