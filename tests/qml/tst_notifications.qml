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
    function test_unownedCenterResponsesCannotRetireAppRead_data() {
        return [
            {tag: "timeline", patch: {view: "timeline"}}
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
