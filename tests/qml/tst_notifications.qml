import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "Notifications"
    width: 1100
    height: 650
    visible: true
    when: windowShown

    Component {
        id: stateComponent
        Activity.NotificationState {}
    }
    Component {
        id: controllerComponent
        Activity.NotificationController {}
    }
    Component {
        id: contentComponent
        Activity.NotificationContent {}
    }
    Component {
        id: fakeBackendComponent
        Activity.NotificationBackend {
            property var requestedCursor: null
            property bool requestedRefresh: false
            property bool requestedDnd: false
            property var requestedUntil: null
            property int dndCalls: 0
            function setDnd(enabled: bool, until: var): bool {
                requestedDnd = enabled;
                requestedUntil = until;
                dndCalls++;
                return true;
            }
            active: false
            function loadHistory(cursor: var, refresh: bool): bool {
                requestedCursor = cursor;
                requestedRefresh = refresh;
                return true;
            }
        }
    }

    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function notification(id, app) {
        return {
            id: id,
            app_name: app || "Chat",
            group_key: app || "chat",
            summary: "Message " + id,
            body: "Body " + id,
            created_unix_ms: id * 1000,
            actions: [
                {
                    key: "inline-reply",
                    label: "Reply"
                },
                {
                    key: "open",
                    label: "Open"
                }
            ]
        };
    }
    function record(id, app) {
        return {
            history_id: id,
            notification: notification(id, app)
        };
    }
    function page(records, cursor, revision, query, anchorReached) {
        return {records: records, next_cursor: cursor || null, epoch: "test-epoch", revision: revision || "1", query: query || "", anchor_reached: anchorReached !== false, scope_limit: 5000};
    }
    // Presentation tests supply authoritative pages, not a second native catalog.
    function project(state, records, cursor) {
        state.historyStaging = [];
        state.stagingEpoch = "";
        state.stagingRevision = "";
        state.applyHistory(page(records, cursor, "1", state.historyQuery), true, null);
    }
    function makeState() {
        const state = createTemporaryObject(stateComponent, testCase);
        verify(state !== null);
        state.notifications = {
            available: true,
            count: 2,
            dnd: false
        };
        state.notificationActive = {
            notifications: [notification(1), notification(100)]
        };
        project(state, [record(100), record(3), record(2), record(1)]);
        return state;
    }
    function makeController(state) {
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state,
            width: testCase.width,
            height: testCase.height
        });
        verify(controller !== null);
        controller.rebuildRecords();
        return controller;
    }
    function test_dndAcknowledgementAndRetry() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {
            store: state
        });
        compare(state.dndDurationMinutes, 30);
        state.setDndDuration(60);
        compare(state.dndDurationMinutes, 60);
        compare(state.backend.dndCalls, 0);
        const now = Date.now();
        verify(state.setDndEnabled(true));
        verify(state.backend.requestedDnd);
        verify(state.backend.requestedUntil >= now + 3600000);
        verify(!state.notifications.dnd, "daemon owns acknowledged DND state");
        verify(state.dndPending);
        verify(!state.setDndEnabled(false), "one outstanding DND request");
        state.finishDnd(null, "Disconnected");
        compare(state.dndError, "Disconnected");
        verify(!state.notifications.dnd);
        state.retryDnd();
        compare(state.backend.dndCalls, 2);
        state.finishDnd({available: true, dnd: true}, "");
        verify(state.notifications.dnd);
        state.setDndDuration(0);
        compare(state.backend.requestedUntil, null);
        verify(state.dndPending);
        state.finishDnd({available: true, dnd: true, dnd_until_unix_ms: null}, "");
        state.setDndEnabled(false);
        verify(!state.backend.requestedDnd);
        compare(state.backend.requestedUntil, null);
    }
    function test_refreshStagesAuthoritativePagesUntilVisibleAnchor() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {store: state});
        state.historyEnabled = true;
        state.reloadHistory();
        compare(state.historyAnchor.id, 1);
        const first = Array.from({length: 50}, (_, index) => record(100 - index));
        state.applyHistory(page(first, "opaque-next", "2", "", false), true, null);
        compare(state.backend.requestedCursor, "opaque-next");
        verify(state.backend.requestedRefresh);
        verify(state.historyLoading);
        compare(state.history.length, 4, "old window remains until replacement is complete");
        const rest = Array.from({length: 50}, (_, index) => record(50 - index));
        state.applyHistory(page(rest, null, "2"), true, "opaque-next");
        compare(state.history.length, 100);
        verify(!state.historyLoading);
        state.reloadHistory();
        state.applyHistory(page([], null, "3"), true, null);
        compare(state.history.length, 0, "refresh removes absent rows instead of union-merging them");
    }
    function test_replyAcknowledgementAndFailure() {
        const state = makeState();
        const key = state.keyFor(100);
        state.setDraft(key, "Hello");
        verify(state.replyNotification(key, "Hello"));
        compare(state.drafts[key], "Hello");
        verify(state.replies[key].pending);
        verify(!state.replyNotification(key, "Hello"));
        state.reloadHistory();
        const history = Object.keys(state.backend.requests).find(id => id.startsWith("history-"));
        state.backend.finish(history, {}, "Read failed");
        verify(!state.historyLoading);
        compare(state.historyError, "Read failed");
        verify(state.replies[key].pending, "a read failure cannot retire the reply");
        const failed = Object.keys(state.backend.requests).find(id => id.startsWith("reply-"));
        state.backend.acceptSharedResponse(failed, null, "Connection lost");
        compare(state.drafts[key], "Hello");
        verify(!state.replies[key].pending);
        compare(state.replies[key].error, "Connection lost");
        verify(state.replyNotification(key, "Hello"));
        const retried = Object.keys(state.backend.requests).find(id => id.startsWith("reply-"));
        state.backend.finish(retried, {}, "");
        compare(state.drafts[key], undefined);
        state.setDraft(key, "Newer draft");
        state.finishReply(key, "Older draft", "");
        compare(state.drafts[key], "Newer draft");
    }
    function test_liveUpdateRetainsReplyDelegateAndFocus() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        controller.openDetails();
        state.setDraft(100, "Draft");
        const content = createTemporaryObject(contentComponent, controller, {
            controller: controller,
            width: 453,
            height: 600
        });
        verify(content !== null);
        wait(50);
        const row = findChild(content, "notificationHistoryRow-100");
        verify(row !== null);
        const field = findChild(row, "notificationReplyInput");
        verify(field !== null);
        field.focusInput(false);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_T);
        compare(state.drafts[state.keyFor(100)], "Draft", "reply typing is local until save");
        state.notificationActive = {
            notifications: [notification(101), notification(100), notification(1)]
        };
        project(state, [record(101), record(100), record(3), record(2), record(1)]);
        wait(50);
        compare(findChild(content, "notificationHistoryRow-100"), row);
        verify(field.inputActiveFocus);
        compare(field.text, "Draftt");
        // More than the generic model's reorder/chunk thresholds: live reply
        // editors still move with their stable identity, never a reset.
        const burst = Array.from({
            length: 205
        }, (_, index) => notification(index + 1000));
        state.notificationActive = {
            notifications: burst.concat([notification(100), notification(1)])
        };
        state.history = burst.map(n => ({history_id: null, notification: n})).concat([record(100), record(3), record(2), record(1)]);
        wait(50);
        compare(findChild(content, "notificationHistoryRow-100"), row);
        verify(field.inputActiveFocus);
        compare(field.text, "Draftt");
        keyClick(Qt.Key_Return);
        compare(state.drafts[state.keyFor(100)], "Draftt");
        content.destroy();
        wait(50);
    }
    function test_selectedCommandsWorkWithoutOpeningDetails() {
        const state = makeState();
        const live = notification(100);
        live.actions = [{key: "default", label: "Open"}, {key: "mail-reply-sender", label: "Reply in app"}, {key: "inline-reply", label: "Reply here"}];
        state.notificationActive = {notifications: [live]};
        project(state, [{history_id: null, notification: live}, record(3), record(2), record(1)]);
        const controller = makeController(state);
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        content.listItem.focusList();
        const sent = () => testCase.calls.filter(call => call.method === "notifications.invokeAction");
        let before = sent().length;
        keyClick(Qt.Key_Return);
        compare(sent().length, before + 1);
        compare(sent()[before].params.action_key, "default");
        verify(!controller.detailsOpen);
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(sent().length, before + 1, "pending invocation cannot repeat");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("action-")), {}, "App unavailable");
        compare(state.lastError, "App unavailable");
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => content.detailsNavigation.commandMenuOpen);
        const menu = findChild(content, "detailsCommandMenu");
        verify(menu.width > 0 && menu.height > 0, "menu is visible even with collapsed details");
        const dismissCount = testCase.calls.filter(call => call.method === "notifications.dismiss").length;
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(testCase.calls.filter(call => call.method === "notifications.dismiss").length, dismissCount, "menu owns command chords");
        keyClick(Qt.Key_Return);
        compare(sent().length, before + 2);
        compare(sent()[before + 1].params.action_key, "mail-reply-sender", "ordinary reply is an app action");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("action-")), {}, "");
        keyClick(Qt.Key_R, Qt.AltModifier);
        tryVerify(() => controller.detailsOpen);
        tryVerify(() => findChild(content, "notificationReplyInput") !== null);
        const field = findChild(content, "notificationReplyInput");
        tryVerify(() => field.inputActiveFocus);
        keyClick(Qt.Key_H);
        keyClick(Qt.Key_I);
        const repliesBefore = testCase.calls.filter(call => call.method === "notifications.reply").length;
        keyClick(Qt.Key_Return);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore, "field save is not send");
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore + 1);
        const reply = testCase.calls.filter(call => call.method === "notifications.reply").pop();
        compare(reply.params.id, 100);
        compare(reply.params.text, "hi");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("reply-")), {}, "");
        state.setDraft(controller.selectedKey, "Saved draft");
        controller.closeDetails();
        content.listItem.focusList();
        keyClick(Qt.Key_R, Qt.AltModifier);
        tryVerify(() => controller.detailsOpen);
        tryVerify(() => findChild(content, "notificationReplyInput") !== null && findChild(content, "notificationReplyInput").inputActiveFocus);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore + 1, "Alt+R from results opens the saved draft, not sends it");
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").pop().params.text, "Saved draftx");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("reply-")), {}, "");
        compare(findChild(content, "notificationReplyInput").text, "", "acknowledgement clears the saved editor binding");
        verify(!content.detailsNavigation.editing);
        controller.closeDetails();
        controller.select(1); // closed historical notification
        verify(!controller.selectedLive);
        content.listItem.focusList();
        keyClick(Qt.Key_Return);
        verify(controller.detailsOpen, "no default action means inspect, never dismiss");
        compare(sent().length, before + 2);
        content.destroy();
        wait(0);
    }
    function test_recordIdentityAndConnectionGenerationFenceDraftsAndHistory() {
        const state = makeState();
        const oldKey = state.keyFor(100);
        state.setDraft(oldKey, "Old draft");
        verify(state.replyNotification(oldKey, "Old draft"));
        const pendingReply = Object.keys(state.backend.requests).find(key => key.startsWith("reply-"));
        const reused = Object.assign({}, notification(100), {created_unix_ms: 999999});
        state.notificationActive = {available: true, notifications: [reused]};
        const newKey = state.keyFor(100);
        verify(oldKey !== newKey);
        state.setDraft(newKey, "New draft");
        state.backend.finish(pendingReply, {}, "");
        compare(state.drafts[oldKey], undefined);
        compare(state.drafts[newKey], "New draft", "old acknowledgement cannot clear another conversation");
        verify(!state.isLive(notification(100)));
        verify(!state.replyNotification(oldKey, "Stale"));
        state.reloadHistory();
        const pendingHistory = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.connectionLost();
        verify(!state.isLive(reused), "cached rows are not actionable while disconnected");
        state.backend.finish(pendingHistory, {notification_page: page([record(987)])}, "");
        verify(!state.history.some(record => record.history_id === 987));
        state.applySnapshot({notifications: {available: true, history_revision: 0}, notification_active: {available: true, revision: 0, notifications: [reused]}});
        verify(state.isLive(reused), "a new generation accepts reset revisions");
        compare(state.drafts[newKey], "New draft");
    }
    function test_coalescedTransientReplacementThenClose() {
        const state = makeState();
        state.applySnapshot({notifications: {available: true, history_revision: 1}, notification_active: {available: true, revision: 1, notifications: [notification(1)]}});
        project(state, [record(1)]);
        state.backend.snapshot();
        const oldSnapshot = Object.keys(state.backend.requests).find(id => id.startsWith("snapshot-"));
        state.queueEvent(false, {available: true, revision: 2, notifications: [Object.assign({}, notification(1), {hints: {transient: true}})]});
        state.queueEvent(false, {available: true, revision: 3, notifications: []});
        state.queueEvent(true, {available: true, history_revision: 3});
        state.flushEvents();
        state.backend.finish(oldSnapshot, {snapshot: {notification_active: {available: true, revision: 1, notifications: [notification(1)]}}}, "");
        compare(state.notificationActive.revision, 3, "a stale snapshot cannot undo newer events");
        state.reloadHistory();
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(request, {notification_page: page([], null, "3")}, "", "");
        compare(state.recentNotifications.length, 0, "coalescing cannot retain deleted persisted content");
    }
    function test_transientReplacementAndStaleHistoryCannotResurrectClosedRows() {
        const state = makeState();
        state.applySummary({available: true, history_revision: 1});
        state.reloadHistory();
        const pendingHistory = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        const transient = Object.assign({}, notification(1), {hints: {transient: true}});
        state.applySnapshot({notifications: {available: true, history_revision: 2}, notification_active: {available: true, revision: 2, notifications: [transient]}});
        compare(state.history.length, 4, "only authoritative query pages replace the window");
        state.applySnapshot({notifications: {available: true, history_revision: 3}, notification_active: {available: true, revision: 3, notifications: []}});
        state.backend.finish(pendingHistory, {notification_page: page([record(1)])}, "", "");
        verify(state.historyDirty, "changed revisions trigger a fresh read instead of merging stale content");
        state.reloadHistory();
        const current = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(current, {notification_page: page([record(3), record(2)], null, "3")}, "", "");
        verify(!state.history.some(record => record.history_id === 1), "refresh removes deleted content");
    }
    function test_prependAndHistoryAppendPreserveViewportAnchor() {
        const state = makeState();
        const records = Array.from({length: 45}, (_, index) => notification(1000 - index));
        state.notificationActive = {available: true, notifications: records};
        project(state, records.map(n => ({history_id: null, notification: n})), "next-older");
        const controller = makeController(state);
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        const list = findChild(content, "resultListView");
        tryCompare(list, "count", 45);
        controller.select(12);
        wait(30);
        list.positionViewAtIndex(10, ListView.Beginning);
        const anchor = content.listItem.sessionState().viewport;
        verify(anchor !== null);
        const selected = controller.selectedKey;
        state.notificationActive = {available: true, notifications: [notification(2000)].concat(records)};
        project(state, [notification(2000)].concat(records).map(n => ({history_id: null, notification: n})), "next-older");
        wait(40);
        compare(controller.selectedKey, selected);
        compare(content.listItem.sessionState().viewport.key, anchor.key);
        verify(Math.abs(content.listItem.sessionState().viewport.offset - anchor.offset) < 1);
        state.applyHistory(page(Array.from({length: 50}, (_, index) => record(900 - index))), false, "next-older");
        wait(40);
        compare(content.listItem.sessionState().viewport.key, anchor.key);
        compare(list.count, 96, "single-app history uses notification rows, not eager group expansion");
        content.destroy();
        wait(0);
    }
    function test_keyboardSearchUsesNativeCatalogAndRejectsSupersededReplies() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        state.historyEnabled = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        tryCompare(state, "historyLoading", true);
        const initial = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.setDraft(100, "Keep my draft");
        content.listItem.focusSearch();
        keyClick(Qt.Key_N);
        keyClick(Qt.Key_E);
        keyClick(Qt.Key_E);
        keyClick(Qt.Key_D);
        keyClick(Qt.Key_L);
        keyClick(Qt.Key_E);
        compare(controller.filterText, "needle");
        compare(state.historyQuery, "needle");
        state.backend.finish(initial, {notification_page: page([record(888)])}, "", "");
        compare(state.history.length, 0, "an old query cannot repopulate new search results");
        tryCompare(state, "historyLoading", true);
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-") && state.backend.requests[key].historyGeneration === state.historyGeneration);
        const call = testCase.calls.filter(call => call.method === "notifications.queryHistory").pop();
        compare(call.params.query, "needle");
        compare(call.params.cursor, null);
        const found = record(900);
        found.notification.summary = "Needle from previously unloaded history";
        state.backend.finish(request, {notification_page: page([found], "query-page-2", "9", "needle")}, "", "");
        tryCompare(controller.notificationModel, "count", 1);
        compare(controller.selectedNotification.id, 900);
        compare(state.drafts["100:100000"], "Keep my draft");
        // Pagination remains enabled for search, and consumes the opaque cursor.
        state.loadMoreHistory();
        const next = testCase.calls.filter(call => call.method === "notifications.queryHistory").pop();
        compare(next.params.cursor, "query-page-2");
        compare(next.params.query, "needle");
        content.destroy();
        wait(0);
    }
    function test_cursorInvalidationAndMalformedPagesNeverMixVisibleRevisions() {
        const state = makeState();
        project(state, [record(100), record(3)], "old-cursor");
        state.historyDirty = false;
        state.loadMoreHistory();
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(request, {}, "History changed", "history-cursor-stale");
        verify(state.historyDirty);
        compare(state.history.length, 2, "stale reads retain the current visible window until refresh");
        verify(!state.historyHasMore);
        state.reloadHistory();
        const refresh = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(refresh, {notification_page: page([record(101), record(100)], "new-cursor", "2")}, "", "");
        compare(state.historyRevision, "2");
        verify(!state.history.some(item => item.history_id === 3), "refresh removes absent records");
        state.applyHistory(page([record(99)], null, "3"), false, "new-cursor");
        compare(state.history.length, 2, "a different page revision is never appended");
        verify(state.historyDirty);
        project(state, [record(100)], "cursor");
        state.applyHistory(page([], "cursor"), false, "cursor");
        verify(state.historyError.length > 0, "non-advancing pages fail instead of looping");
        compare(state.history.length, 1);
        state.applyHistory(page([record(100)], null), false, "cursor");
        compare(state.history.length, 1, "duplicate pages are rejected, not silently deduplicated");
        state.applyHistory(page([{notification: {id: 99}}]), false, "cursor");
        compare(state.history.length, 1, "malformed identities cannot enter the keyed model");
        // Reconnect can legitimately reset revision numbers and changes epoch.
        state.connectionLost();
        state.reloadHistory();
        const reconnect = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        const replacement = page([], null, "0");
        replacement.epoch = "new-daemon";
        state.backend.finish(reconnect, {notification_page: replacement}, "", "");
        compare(state.historyEpoch, "new-daemon");
        compare(state.history.length, 0, "missed deletion events are repaired by authoritative replacement");
    }
}
