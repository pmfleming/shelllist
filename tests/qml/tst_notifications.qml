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

    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function notification(id, name) {
        return {id: id, app_name: name || "Chat", group_key: name || "chat", summary: "Message " + id,
            body: "Body " + id, created_unix_ms: id * 1000,
            actions: [{key: "inline-reply", label: "Reply"}, {key: "open", label: "Open"}]};
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
    function preview(id, name) { return Object.assign(notification(id, name), {app_key: name || "Chat", app_icon: "", closed_unix_ms: null}); }
    function app(id, name, count) { return {key: name || "Chat", count: count || 1, total_count: count || 1, latest: preview(id, name)}; }
    function appPage(apps, query, offset, next, total) {
        return {view: "apps", epoch: "test-epoch", revision: "1", query: query || "", apps: apps,
            offset: offset || 0, next_offset: next === undefined ? null : next, total_apps: total || apps.length, anchor_reached: true};
    }
    function startCenter() {
        const state = makeState();
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state, uiActive: true, width: testCase.width, height: testCase.height
        });
        verify(controller !== null);
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
    function test_freshStoreCutoverRetiresOldSessionAndAcceptsEmptyHistory() {
        const controller = startCenter(), state = controller.notificationState;
        const catalog = controller.catalog, timeline = controller.timeline;
        finishApps(controller, Object.assign(appPage([app(100)], "", 0, 1, 300), {revision: "90"}));
        compare(catalog.apps.length, 1, "cutover starts from a genuinely accepted window");
        compare(catalog.revision, "90");
        state.acceptedHistoryRevision = 90;
        state.acceptedActiveRevision = 80;
        state.setDraft(notification(1), "Unsent text");
        const draftKey = state.keyFor(notification(1));
        state.deleteConfirmation = {token: "old-store-token", expires_unix_ms: Date.now() + 60000};
        state.deletePreparing = true;
        state.operations = {"1000:1": true};
        state.policyPending = {Chat: true};
        state.settingsPending = true;
        state.dndPending = true;
        state.sharingPending = true;
        timeline.snapshot = {epoch: "old", revision: "90", recent: [preview(100)], next_offset: 200};
        timeline.entries = [preview(100)];
        timeline.windowOffset = 180;
        controller.appViews = {Chat: {date: "older"}};
        state.backend.queryCenter({view: "apps"}, {view: "apps", generation: catalog.rootGeneration, query: "", revision: 90});
        const lateId = Object.keys(state.backend.requests).find(id => state.backend.requests[id].kind === "center");
        verify(!!lateId);
        state.backend.transportFailed("Daemon restarting", []);
        compare(state.activeRecords.length, 0);
        compare(state.notificationActive.notifications.length, 0);
        compare(state.deleteConfirmation, null);
        verify(!state.deletePreparing && !state.deletePending);
        verify(!state.settingsPending && !state.dndPending && !state.sharingPending);
        compare(Object.keys(state.operations).length, 0);
        compare(Object.keys(state.policyPending).length, 0);
        compare(catalog.apps.length, 0);
        compare(catalog.windowOffset, 0);
        compare(catalog.epoch, "");
        compare(timeline.entries.length, 0);
        compare(Object.keys(timeline.snapshot).length, 0);
        compare(timeline.windowOffset, 0);
        compare(Object.keys(controller.appViews).length, 0);
        compare(state.drafts[draftKey], "Unsent text");
        const callsBefore = calls.length;
        state.confirmDelete();
        compare(calls.length, callsBefore, "old deletion token cannot be submitted after reconnect");
        state.backend.finish(lateId, {notification_center: appPage([app(100)])}, "", "");
        compare(catalog.apps.length, 0, "old read cannot repopulate the cleared catalog");
        state.applySnapshot({
            notifications: {available: true, backend: "native", count: 0, dnd: false, history_revision: 0,
                settings: {countdown: true, code_expiry_seconds: 0, history_days: 30}, app_policies: {}},
            notification_active: {available: true, revision: 0, notifications: []}
        });
        compare(state.acceptedHistoryRevision, 0);
        compare(state.acceptedActiveRevision, 0);
        compare(state.settings.history_days, 30);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([]), {epoch: "v2-session", revision: "0"}));
        compare(catalog.epoch, "v2-session");
        compare(catalog.apps.length, 0);
        compare(catalog.rootError, "");
        state.applyActive({available: true, revision: 1, notifications: [notification(2)]});
        verify(state.isActive(2), "new delivery works after the empty-store cutover");
        verify(!state.isActive(1));
    }
    function test_stalePagesNeverMixVisibleRevisionsAndGapsRefreshReads() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        finishApps(controller, appPage([app(100), app(3, "Mail")], "", 0, 2, 3));
        catalog.rootDirty = false; catalog.loadMore();
        finishApps(controller, null, "History changed", "history-cursor-stale");
        verify(catalog.rootDirty);
        compare(catalog.apps.length, 2);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([app(101)], "", 0, 1, 2), {revision: "2"}));
        compare(catalog.revision, "2");
        compare(catalog.apps.length, 1, "refresh removes absent apps");
        catalog.rootDirty = false; catalog.loadMore();
        finishApps(controller, Object.assign(appPage([app(99, "Other")], "", 1, null, 2), {revision: "3"}));
        compare(catalog.apps.length, 1);
        verify(catalog.rootDirty);
        for (const page of [appPage([], "", 1, 1, 2), appPage([app(100)], "", 1, null, 2), appPage([app(0)], "", 1, null, 2)]) {
            catalog.reloadApps(); finishApps(controller, appPage([app(100)], "", 0, 1, 2));
            catalog.rootDirty = false; catalog.loadMore();
            finishApps(controller, page);
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
