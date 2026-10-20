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
