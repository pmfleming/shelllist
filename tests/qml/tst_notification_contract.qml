pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "NotificationActionContract"
    when: windowShown
    property var loadedFixture: null
    Component { id: factory; Activity.NotificationState { resident: true; uiActive: true } }
    function fixture() {
        if (!loadedFixture) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-notification-actions.json"), false);
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
    function requests(state) { return calls.filter(call => call.route.consumerId === state.backend.sharedConsumerId); }
    function mutations(state) { return requests(state).filter(call => call.method.startsWith("notifications.")); }
    function lastCall(state, method) {
        const found = requests(state).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method);
        return found[found.length - 1];
    }
    function reply(call, value) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(value), "", call.route);
    }
    function event(state, name) {
        const route = Object.assign({}, lastCall(state, "bar.snapshot").route, {kind: "base-subscription", localId: "session-subscribe"});
        emitBaseEvent("bar-daemon", route, clone(fixture().events[name]));
        state.flushEvents();
    }
    function make() {
        const state = createTemporaryObject(factory, tests);
        verify(state !== null);
        reply(lastCall(state, "bar.snapshot"), fixture().snapshot);
        verify(state.nativeAvailable && state.isActive(1));
        return state;
    }
    function startReply(state) {
        const example = fixture().replies.reply;
        const params = example.params;
        verify(state.replyNotification(params.id, params.text));
        const call = lastCall(state, example.method);
        compare(call.params, params, "Requests must match live producer DTOs");
        verify(state.backend.isPending(call.route.localId));
        return call;
    }
    function test_replyCompletionCannotClearANewerDraftOrReusedId() {
        const state = make();
        const oldIdentity = state.keyFor(1);
        const call = startReply(state);
        state.setDraft(oldIdentity, "A newer unsent draft");
        event(state, "replaced");
        const newIdentity = state.keyFor(1);
        verify(newIdentity !== oldIdentity);
        state.setDraft(newIdentity, "Draft for the new notification");
        reply(call, fixture().replies.reply.success);
        compare(state.drafts[oldIdentity], "A newer unsent draft");
        compare(state.drafts[newIdentity], "Draft for the new notification");
        compare(mutations(state).length, 1);
    }
}
