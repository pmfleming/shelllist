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
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(fixture().events[name]), route);
        state.flushEvents();
    }
    function make() {
        const state = createTemporaryObject(factory, tests);
        verify(state !== null);
        reply(lastCall(state, "bar.snapshot"), fixture().snapshot);
        verify(state.nativeAvailable && state.isActive(1));
        return state;
    }
    function prepare(state, key) {
        if (["delete", "cancelDelete"].includes(key)) {
            verify(state.prepareDelete("", null, "All notifications"));
            reply(lastCall(state, "notifications.prepareDelete"), fixture().replies.prepareDelete.success);
            verify(state.deleteConfirmation !== null);
        }
    }
    function start(state, key) {
        const example = fixture().replies[key];
        const params = example.params;
        let sent = false;
        switch (key) {
        case "setDnd": state.dndDurationMinutes = 0; sent = state.setDndEnabled(params.enabled); break;
        case "setAppPolicy": sent = state.setAppPolicy(params.app_key, clone(params.policy)); break;
        case "prepareDelete": sent = state.prepareDelete("", null, "All notifications"); break;
        case "delete": state.confirmDelete(); sent = state.deletePending; break;
        case "cancelDelete": state.cancelDelete(); sent = true; break;
        case "dismiss": sent = state.dismissNotification(params.id); break;
        case "clear": sent = state.clearNotifications(); break;
        case "clearGroup": sent = state.clearNotificationGroup(params.group_key); break;
        case "snooze":
            // Fix the deadline for the contract test; duration calculation is UI-local.
            sent = state.beginOperation(params.id) && state.backend.snooze(params.id, params.until_unix_ms); break;
        case "invokeAction": sent = state.invokeNotificationAction(params.id, params.action_key); break;
        case "reply": sent = state.replyNotification(params.id, params.text); break;
        }
        verify(sent, key);
        const call = lastCall(state, example.method);
        compare(call.params, params, "Requests must match live producer DTOs");
        verify(state.backend.isPending(call.route.localId));
        return call;
    }
    function verifyReleased(state, call) {
        verify(!state.backend.isPending(call.route.localId));
        verify(!state.backend.requests[call.route.localId]);
        verify(!state.dndPending && !state.deletePending && !state.deletePreparing);
        compare(Object.keys(state.operations).length, 0);
        compare(Object.keys(state.policyPending).length, 0);
    }
    function test_outcomes_data() {
        // Preserve distinct draft, consent, policy and active-record error owners.
        // Race tests below and native notification workflows cover ordinary acks.
        return [["setAppPolicy", "failed"], ["prepareDelete", "failed"],
                ["invokeAction", "stale"], ["snooze", "success"]]
            .map(([key, outcome]) => ({tag: key + "/" + outcome, key: key, outcome: outcome}));
    }
    function test_outcomes(data) {
        const state = make();
        prepare(state, data.key);
        const count = mutations(state).length;
        const active = JSON.stringify(state.activeRecords);
        const summary = JSON.stringify(state.notifications);
        const identity = state.keyFor(1);
        const call = start(state, data.key);
        compare(JSON.stringify(state.activeRecords), active, "Sending cannot optimistically remove notifications");
        compare(JSON.stringify(state.notifications), summary, "Sending cannot optimistically change settings");
        const response = fixture().replies[data.key][data.outcome];
        reply(call, response);
        verifyReleased(state, call);
        compare(JSON.stringify(state.activeRecords), active, "Acks are not active-state events");
        if (response.ok) {
            if (["setDnd", "setAppPolicy"].includes(data.key)) compare(state.notifications, response.data.notifications);
            if (data.key === "prepareDelete") compare(state.deleteConfirmation, response.data.delete_confirmation);
            compare(state.lastError, "");
        } else if (data.key !== "cancelDelete") {
            compare(state.lastError, response.error.message);
            if (data.key === "setDnd") compare(state.dndError, response.error.message);
            if (data.key === "setAppPolicy") compare(state.policyErrors[call.params.app_key], response.error.message);
        }
        if (data.key === "reply") {
            verify(!state.replies[identity].pending);
            compare(state.drafts[identity] || "", response.ok ? "" : call.params.text, "Unacknowledged replies retain their draft");
        }
        if (data.key === "delete") compare(state.deleteConfirmation, null, "Consumed deletion consent is never reused");
        compare(mutations(state).length, count + 1, "Errors and stale IDs cannot replay an effect");
    }
    function test_timeoutsDoNotReplay_data() {
        return ["reply"].map(key => ({tag: key, key: key}));
    }
    function test_timeoutsDoNotReplay(data) {
        const state = make();
        prepare(state, data.key);
        const identity = state.keyFor(1);
        const call = start(state, data.key);
        const count = mutations(state).length;
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, null, "Notification outcome unknown", call.route);
        verifyReleased(state, call);
        verify(state.backend.ready && state.nativeAvailable, "A single timeout is not a disconnect");
        wait(0);
        compare(mutations(state).length, count);
        if (data.key === "reply") {
            compare(state.drafts[identity], call.params.text);
            compare(state.replies[identity].error, "Notification outcome unknown");
        }
        if (["prepareDelete", "delete", "cancelDelete"].includes(data.key)) compare(state.deleteConfirmation, null);
    }
    function test_reconnectNeverReplays_data() {
        return ["reply"].map(key => ({tag: key, key: key}));
    }
    function test_reconnectNeverReplays(data) {
        const state = make();
        prepare(state, data.key);
        const call = start(state, data.key);
        const count = mutations(state).length;
        const identity = state.keyFor(1);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Notification outcome unknown");
        verifyReleased(state, call);
        verify(!state.notifications.available);
        const reads = requests(state).filter(call => call.method === "bar.snapshot").length;
        clientReady = true;
        compare(requests(state).filter(call => call.method === "bar.snapshot").length, reads + 1);
        reply(lastCall(state, "bar.snapshot"), fixture().snapshot);
        verify(state.nativeAvailable);
        wait(0);
        compare(mutations(state).length, count, "Recovery may refresh state, never resend actions, replies, settings or deletion consent");
        if (data.key === "reply") {
            compare(state.drafts[identity], call.params.text);
            verify(!state.replies[identity].pending);
            compare(state.replies[identity].error, "Notification outcome unknown");
        }
        // A late old-generation completion must not clear the retained reply draft.
        reply(call, fixture().replies[data.key].success);
        compare(mutations(state).length, count);
        if (data.key === "reply") compare(state.drafts[identity], call.params.text);
    }
    function test_actionEventBeforeAcknowledgementClearsOnlyItsPendingIdentity() {
        const state = make();
        const identity = state.keyFor(1);
        const call = start(state, "invokeAction");
        event(state, "closed");
        compare(state.activeRecords.length, 0);
        verify(state.operations[identity]);
        reply(call, fixture().replies.invokeAction.success);
        verifyReleased(state, call);
        compare(state.activeRecords.length, 0);
        verify(!state.invokeNotificationAction(1, "open"));
        compare(mutations(state).length, 1);
    }
    function test_replyCompletionCannotClearANewerDraftOrReusedId() {
        const state = make();
        const oldIdentity = state.keyFor(1);
        const call = start(state, "reply");
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
    function test_ownedCompletionFlushesEventsButDuplicatesCannotRetireANewerRequest() {
        const state = make();
        const old = start(state, "setDnd");
        const route = Object.assign({}, lastCall(state, "bar.snapshot").route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(fixture().events.dndCleared), route);
        verify(state.queuedSummary !== null);
        reply(old, fixture().replies.setDnd.success);
        compare(state.queuedSummary, null, "queued observations precede acknowledgement");
        verify(!state.notifications.dnd);
        const current = start(state, "setDnd");
        // Exercise the domain boundary too, not only the transport's duplicate fence.
        state.backend.finish(old.route.localId, {}, "Late duplicate failure", "failed");
        verify(state.dndPending);
        compare(state.lastError, "");
        verify(!!state.backend.requests[current.route.localId]);
        reply(current, fixture().replies.setDnd.success);
        verify(state.notifications.dnd);
        compare(mutations(state).length, 2);
    }
    function test_obsoletePreparationIsConsumedWithoutPublishingOrFlushingCurrentEvents() {
        const state = make();
        const call = start(state, "prepareDelete");
        state.connectionLost(); // Retire the domain generation before its reply arrives.
        state.queueEvent(true, clone(fixture().events.dndCleared.data));
        state.lastError = "Current connection failure";
        reply(call, fixture().replies.prepareDelete.success);
        verify(!state.backend.requests[call.route.localId]);
        verify(state.queuedSummary !== null, "obsolete requests cannot flush the new generation");
        verify(!state.notifications.available);
        compare(state.deleteConfirmation, null);
        compare(state.lastError, "Current connection failure");
        compare(mutations(state).length, 1, "no consent or follow-up effect from an obsolete reply");
        state.flushEvents();
        verify(state.notifications.available);
    }
    function test_operationSnapshotsRespectErrorsAndEventVersion_data() {
        return [{tag: "current", outcome: "success", stale: false},
            {tag: "newer-event", outcome: "success", stale: true},
            {tag: "failed", outcome: "stale", stale: false}];
    }
    function test_operationSnapshotsRespectErrorsAndEventVersion(data) {
        const state = make();
        const call = start(state, "invokeAction");
        if (data.stale) event(state, "dndCleared");
        const response = clone(fixture().replies.invokeAction[data.outcome]);
        response.data = {snapshot: clone(fixture().snapshot.data.snapshot)};
        response.data.snapshot.notifications.dnd = true;
        reply(call, response);
        verifyReleased(state, call);
        compare(state.notifications.dnd, data.outcome === "success" && !data.stale);
        compare(state.lastError, response.ok ? "" : response.error.message);
        compare(mutations(state).length, 1, "snapshot handling cannot replay the action");
    }
    function test_cancelAcknowledgementCannotPublishSnapshotOrClearAnotherError() {
        const state = make();
        prepare(state, "cancelDelete");
        const call = start(state, "cancelDelete");
        state.lastError = "Independent failure";
        const response = clone(fixture().replies.cancelDelete.success);
        response.data.snapshot = clone(fixture().snapshot.data.snapshot);
        response.data.snapshot.notifications.dnd = true;
        reply(call, response);
        verifyReleased(state, call);
        verify(!state.notifications.dnd);
        compare(state.lastError, "Independent failure");
        compare(state.deleteConfirmation, null);
    }
}
