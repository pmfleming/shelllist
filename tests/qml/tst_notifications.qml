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
        return state;
    }
    function makeController(state) {
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state,
            width: testCase.width,
            height: testCase.height
        });
        verify(controller !== null);
        projectApps(controller, [app(100, "Chat", 4)]);
        return controller;
    }
    function preview(id, name) { return Object.assign(notification(id, name), {app_key: name || "Chat", app_icon: "", closed_unix_ms: null}); }
    function app(id, name, count) { return {key: name || "Chat", count: count || 1, total_count: count || 1, latest: preview(id, name)}; }
    function appPage(apps, query, offset, next, total) {
        return {view: "apps", epoch: "test-epoch", revision: "1", query: query || "", apps: apps,
            offset: offset || 0, next_offset: next === undefined ? null : next, total_apps: total || apps.length, anchor_reached: true};
    }
    function projectApps(controller, apps) {
        controller.catalog.staging = [];
        controller.catalog.stagingEpoch = "";
        controller.catalog.stagingRevision = "";
        controller.catalog.acceptApps({offset: 0, replacing: true}, appPage(apps, controller.catalog.query));
        compare(controller.catalog.rootError, "");
        controller.rebuildRecords();
    }
    function projectTimeline(controller, previews) {
        controller.timeline.busy = false;
        controller.timeline.requestedDate = previews.length > 3 ? "older" : "";
        controller.timeline.collapsed = previews.length <= 3;
        controller.timeline.snapshot = {recent: previews.slice(0, 3), dates: ["today", "week", "month", "older"].map(key => ({key: key, count: key === "older" ? Math.max(0, previews.length - 3) : 0})), date: controller.timeline.requestedDate, next_offset: null};
        controller.timeline.entries = previews.slice(3).map(p => ({key: p.id + ":" + p.created_unix_ms, preview: p, members: [{id: p.id, created: p.created_unix_ms}]}));
    }
    function startCenter() {
        const controller = makeController(makeState());
        controller.uiActive = true;
        controller.catalog.reloadApps();
        return controller;
    }
    function rootRequest(controller) {
        const requests = controller.notificationState.backend.requests;
        return Object.keys(requests).find(key => requests[key].center?.view === "apps" && requests[key].center.generation === controller.catalog.rootGeneration);
    }
    function finishApps(controller, value, error, code) {
        controller.notificationState.backend.finish(rootRequest(controller), {notification_center: value}, error || "", code || "");
    }
    function stagedPage() { return Object.assign(appPage([app(200, "First")], "", 0, 1, 2), {anchor_reached: false}); }
    function descendants(item) {
        return Array.from(item.children || []).reduce((items, child) => items.concat(descendants(child)), [item]);
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
    function test_replyAcknowledgementAndFailure() {
        const state = makeState();
        const key = state.keyFor(100);
        state.setDraft(key, "Hello");
        verify(state.replyNotification(key, "Hello"));
        compare(state.drafts[key], "Hello");
        verify(state.replies[key].pending);
        verify(!state.replyNotification(key, "Hello"));
        const controller = makeController(state);
        controller.catalog.reloadApps();
        finishApps(controller, null, "Read failed");
        verify(!controller.catalog.rootBusy);
        compare(controller.catalog.rootError, "Read failed");
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
    function test_dateHistoryUsesSharedScrollingAndKeepsAppListFixed() {
        const controller = makeController(makeState());
        projectApps(controller, [app(100, "Chat", 500), app(1, "Mail", 1)]);
        controller.uiActive = true; controller.primarySelected();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(150);
        projectTimeline(controller, Array.from({length: 100}, (_, i) => preview(1000 - i)));
        verify(!findChild(content, "notificationPage"), "transport windows do not create page fields");
        const list = findChild(content, "notificationTimelineList");
        tryCompare(list, "count", 101);
        tryCompare(controller, "detailsExpansionProgress", 1);
        wait(50);
        content.listItem.focusList(); keyClick(Qt.Key_Tab);
        const beforeScroll = list.contentY - list.originY;
        keyClick(Qt.Key_PageDown);
        tryVerify(() => list.contentY - list.originY > beforeScroll, 1000, "shared non-highlighted scrolling fallback handles PageDown relative to ListView's origin");
        const rendered = descendants(list.contentItem).filter(item => String(item.objectName || "").startsWith("notificationPreview-")).length;
        verify(rendered < 25, "virtualization does not instantiate the entire date");
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(controller, "detailsTab", "controls");
        verify(findChild(content, "notificationAppDelivery") !== null);
        compare(controller.notificationModel.count, 2);
        content.listItem.focusList(); keyClick(Qt.Key_Down);
        compare(controller.selectedAppKey, "Mail");
        verify(controller.detailsOpen);
        content.destroy(); wait(0);
    }
    function test_centerRefreshNeverPublishesPartialAppPages() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        tryCompare(controller.catalog, "rootBusy", true);
        const requestFor = () => Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps" && state.backend.requests[key].center.generation === controller.catalog.rootGeneration);
        const first = appPage(Array.from({length: 50}, (_, index) => app(1000 - index, "App" + index)), "", 0, 50, 51);
        first.anchor_reached = false;
        state.backend.finish(requestFor(), {notification_center: first}, "", "");
        compare(controller.visibleApps.length, 1, "incomplete refresh stays private");
        tryVerify(() => requestFor() !== undefined);
        state.backend.finish(requestFor(), {}, "Cannot read history", "unavailable");
        compare(controller.visibleApps.length, 1);
        compare(controller.selectedAppKey, "Chat");
        compare(controller.catalog.staging.length, 0);
        verify(controller.catalog.rootError.length > 0);
        controller.refresh();
        tryVerify(() => requestFor() !== undefined);
        state.backend.finish(requestFor(), {notification_center: appPage([app(99, "Mail")])}, "", "");
        tryCompare(controller, "selectedAppKey", "Mail");
    }
    function test_emptyCenterSettlesAndMalformedSnapshotsFailClosed() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        const catalog = controller.catalog;
        tryCompare(catalog, "rootBusy", true);
        const request = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps");
        state.backend.finish(request, {notification_center: appPage([])}, "", "");
        tryCompare(controller.notificationModel, "count", 0);
        wait(180);
        compare(catalog.rootDirty, false);
        verify(!catalog.rootBusy);
        const before = testCase.calls.filter(call => call.method === "notifications.queryCenter").length;
        wait(180);
        compare(testCase.calls.filter(call => call.method === "notifications.queryCenter").length, before, "empty results do not poll continuously");
        catalog.acceptApps({offset: 0, replacing: true}, appPage([app(100), app(100)]));
        verify(catalog.rootError.length > 0);
        compare(catalog.apps.length, 0);
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
        const controller = makeController(state);
        controller.catalog.reloadApps();
        const pending = rootRequest(controller);
        state.connectionLost();
        verify(!state.isLive(reused), "cached rows are not actionable while disconnected");
        state.backend.finish(pending, {notification_center: appPage([app(987)])}, "");
        verify(!controller.catalog.apps.some(app => app.latest.id === 987));
        state.applySnapshot({notifications: {available: true, history_revision: 0}, notification_active: {available: true, revision: 0, notifications: [reused]}});
        verify(state.isLive(reused), "a new generation accepts reset revisions");
        compare(state.drafts[newKey], "New draft");
    }
    function test_coalescedTransientReplacementThenClose() {
        const state = makeState();
        state.applySnapshot({notifications: {available: true, history_revision: 1}, notification_active: {available: true, revision: 1, notifications: [notification(1)]}});
        const controller = makeController(state);
        state.backend.snapshot();
        const oldSnapshot = Object.keys(state.backend.requests).find(id => id.startsWith("snapshot-"));
        state.queueEvent(false, {available: true, revision: 2, notifications: [Object.assign({}, notification(1), {hints: {transient: true}})]});
        state.queueEvent(false, {available: true, revision: 3, notifications: []});
        state.queueEvent(true, {available: true, history_revision: 3});
        state.flushEvents();
        state.backend.finish(oldSnapshot, {snapshot: {notification_active: {available: true, revision: 1, notifications: [notification(1)]}}}, "");
        compare(state.notificationActive.revision, 3, "a stale snapshot cannot undo newer events");
        controller.catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([]), {revision: "3"}));
        compare(controller.catalog.apps.length, 0, "coalescing cannot retain deleted persisted content");
    }
    function test_keyboardSearchUsesNativeCatalogAndRejectsSupersededReplies() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        const catalog = controller.catalog;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        tryCompare(catalog, "rootBusy", true);
        const initial = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps");
        state.setDraft(100, "Keep my draft");
        content.listItem.focusSearch();
        for (const key of [Qt.Key_N, Qt.Key_E, Qt.Key_E, Qt.Key_D, Qt.Key_L, Qt.Key_E]) keyClick(key);
        compare(controller.filterText, "needle");
        compare(catalog.query, "needle");
        state.backend.finish(initial, {notification_center: appPage([app(888)])}, "", "");
        compare(catalog.apps.length, 0);
        tryCompare(catalog, "rootBusy", true);
        const request = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps" && state.backend.requests[key].center.generation === catalog.rootGeneration);
        const call = testCase.calls.filter(call => call.method === "notifications.queryCenter" && call.params.view === "apps").pop();
        compare(call.params.query, "needle");
        compare(call.params.offset, 0);
        const found = app(900, "Unloaded app", 1);
        found.latest.summary = "Needle from previously unloaded history";
        state.backend.finish(request, {notification_center: appPage([found], "needle")}, "", "");
        tryCompare(controller.notificationModel, "count", 1);
        compare(controller.selectedAppKey, "Unloaded app");
        compare(state.drafts["100:100000"], "Keep my draft");
        content.destroy(); wait(0);
    }
    function test_queuedRevisionBetweenRefreshPagesDiscardsStaging() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, stagedPage());
        compare(catalog.staging.length, 1);
        compare(JSON.stringify(catalog.apps), visible);
        state.queueEvent(true, {available: true, history_revision: 2});
        finishApps(controller, appPage([app(199, "Second")], "", 1, null, 2));
        compare(state.observedHistoryRevision, 2, "flush queued events before accepting a page");
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.staging.length, 0);
        verify(catalog.rootDirty);
        verify(!catalog.rootBusy);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([app(201)]), {revision: "2"}));
        compare(catalog.apps.map(app => app.latest.id), [201]);
        compare(catalog.revision, "2");
    }
    function test_rejectInvalidCenterPages_data() {
        return [
            {tag: "invalid-id", patch: {apps: [app(4294967296)]}}
        ];
    }
    function test_rejectInvalidCenterPages(data) {
        const controller = startCenter(), catalog = controller.catalog;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, Object.assign(appPage([app(99)]), data.patch));
        compare(JSON.stringify(catalog.apps), visible);
        verify(catalog.rootError.length > 0);
        verify(!catalog.rootBusy);
        compare(catalog.staging.length, 0);
    }
    function test_unownedCenterResponsesCannotRetireAppRead_data() {
        return [
            {tag: "timeline", patch: {view: "timeline"}},
            {tag: "old-generation", patch: {generation: -1}}
        ];
    }
    function test_unownedCenterResponsesCannotRetireAppRead(data) {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        finishApps(controller, stagedPage());
        const context = state.backend.requests[rootRequest(controller)].center;
        const visible = JSON.stringify(catalog.apps), staging = JSON.stringify(catalog.staging);
        for (const error of ["", "Unrelated read failed"]) {
            state.centerResponse(Object.assign({}, context, data.patch), appPage([]), error, "");
            verify(catalog.rootBusy, "another reader cannot retire our continuation");
            compare(catalog.rootError, "");
            compare(JSON.stringify(catalog.apps), visible);
            compare(JSON.stringify(catalog.staging), staging);
        }
        finishApps(controller, appPage([app(199, "Second")], "", 1, null, 2));
        compare(catalog.apps.map(app => app.key), ["First", "Second"]);
        verify(!catalog.rootBusy);
    }
    function test_stalePagesNeverMixVisibleRevisionsAndGapsRefreshReads() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        finishApps(controller, appPage([app(100), app(3, "Mail")], "", 0, 2, 3));
        catalog.rootDirty = false; catalog.loadMore();
        finishApps(controller, null, "History changed", "history-cursor-stale");
        verify(catalog.rootDirty);
        compare(catalog.apps.length, 2);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([app(101)]), {revision: "2"}));
        compare(catalog.revision, "2");
        compare(catalog.apps.length, 1, "refresh removes absent apps");
        catalog.acceptApps({offset: 1, replacing: false}, Object.assign(appPage([app(99, "Other")], "", 1, null, 2), {revision: "3"}));
        compare(catalog.apps.length, 1);
        verify(catalog.rootDirty);
        projectApps(controller, [app(100)]);
        for (const page of [appPage([], "", 1, 1, 2), appPage([app(100)], "", 1, null, 2), appPage([app(0)], "", 1, null, 2)]) {
            catalog.acceptApps({offset: 1, replacing: false}, page);
            verify(catalog.rootError.length > 0);
            compare(catalog.apps.length, 1);
        }
        state.connectionLost(); catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([]), {epoch: "new-daemon", revision: "0"}));
        compare(catalog.epoch, "new-daemon");
        compare(catalog.apps.length, 0);
        catalog.rootDirty = false;
        state.backend.eventGapDetected("notifications.changed", {event: "lagged"});
        verify(catalog.rootDirty, "a gap refreshes the active reader even before the next revision");
    }
}
