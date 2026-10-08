import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "NotificationCenter"
    width: 1100; height: 680; visible: true; when: windowShown
    Component { id: stateFactory; Activity.NotificationState {} }
    Component { id: controllerFactory; Activity.NotificationController {} }
    Component { id: contentFactory; Activity.NotificationContent {} }
    function init() { failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign).*/); calls = []; clientReady = true; }
    function preview(id, app) { return {id: id, created_unix_ms: id * 1000, app_key: app, app_name: app, app_icon: "", summary: "Message " + id, body: "Body"}; }
    function make() {
        const state = createTemporaryObject(stateFactory, tests, {uiActive: true});
        state.applySummary({available: true, backend: "native", history_revision: 1, app_policies: {}});
        const controller = createTemporaryObject(controllerFactory, state, {notificationState: state, uiActive: true, width: 1100, height: 650});
        controller.catalog.apps = ["named:Chat", "named:Mail"].map((key, i) => ({key: key, count: 3, total_count: 3, latest: preview(100 - i, key)}));
        controller.rebuildRecords();
        const content = createTemporaryObject(contentFactory, controller, {controller: controller, width: 1100, height: 650});
        verify(content !== null);
        content.listItem.focusList();
        return {state: state, controller: controller, content: content};
    }
    function request(state, prefix) { return Object.keys(state.backend.requests).find(id => id.startsWith(prefix + "-")); }
    function policyCalls() { return calls.filter(c => c.method === "notifications.setAppPolicy"); }
    function showRow(list, index, mode) {
        // A delegate may exist before its nested Loader has any geometry.
        tryVerify(() => {
            list.positionViewAtIndex(index, mode);
            list.forceLayout();
            const row = list.itemAtIndex(index);
            return row !== null && row.height > 0;
        });
        verify(waitForPolish(list.Window.window));
        list.cancelFlick();
        list.positionViewAtIndex(index, mode);
        list.forceLayout();
        verify(waitForPolish(list.Window.window));
    }
    function test_listSilenceAcknowledgesAndAppControlsUseDraftTransactions() {
        const {state, controller, content} = make();
        keyClick(Qt.Key_Q, Qt.AltModifier);
        tryCompare(state, "policyPending", {"named:Chat": true});
        compare(policyCalls().length, 1);
        verify(!state.appPolicy("named:Chat").silent, "requests do not impersonate acknowledged policy");
        keyClick(Qt.Key_Q, Qt.AltModifier);
        compare(policyCalls().length, 1);
        const saved = {silent: true, until_unix_ms: null, group_similar: true, bypass_dnd: false};
        state.backend.finish(request(state, "app-policy"), {notifications: {available: true, backend: "native", history_revision: 2, app_policies: {"named:Chat": saved}}}, "", "");
        verify(state.appPolicy("named:Chat").silent);
        verify(!state.appPolicy("named:Mail").silent);
        controller.openDetails(); controller.setDetailsTab("controls");
        tryVerify(() => findChild(content, "notificationAppDelivery") !== null);
        const choice = findChild(content, "notificationAppDelivery");
        content.detailsNavigation.focusContent(true);
        tryCompare(content.detailsNavigation, "currentTarget", choice);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Up);
        compare(policyCalls().length, 1);
        keyClick(Qt.Key_Escape);
        compare(choice.value, "silent");
        compare(policyCalls().length, 1, "discard never saves a policy");
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Space); keyClick(Qt.Key_Up); keyClick(Qt.Key_Return);
        tryCompare(state, "policyPending", {"named:Chat": true});
        compare(policyCalls().length, 2);
        compare(policyCalls()[1].params.policy.silent, false);
        state.backend.finish(request(state, "app-policy"), {}, "Denied", "");
        compare(choice.value, "silent");
        compare(state.policyErrors["named:Chat"], "Denied");
        content.destroy();
    }
    function test_deleteFromUnselectedRowConfirmsNativeScopeAndNeverReplays() {
        const {state, controller, content} = make();
        tryVerify(() => findChild(content, "notificationDelete-named:Mail") !== null);
        const button = findChild(content, "notificationDelete-named:Mail");
        compare(button.border.width, 0);
        compare(findChild(content, "notificationSilence-named:Mail").border.width, 0);
        mouseClick(button);
        compare(controller.selectedAppKey, "named:Chat", "row deletion does not select an implicit target");
        const prepare = calls.filter(c => c.method === "notifications.prepareDelete").pop();
        compare(prepare.params, {app_key: "named:Mail", selected: null});
        verify(state.deletePreparing);
        const challenge = {token: "owned", count: 300, app_key: "named:Mail", expires_unix_ms: Date.now() + 60000};
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: challenge}, "", "");
        verify(controller.navigationBlocked);
        verify(waitForRendering(findChild(content, "notificationDeleteConfirmation")));
        wait(20);
        keyClick(Qt.Key_Escape);
        tryCompare(state, "deleteConfirmation", null);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "owned", cancel: true});
        state.backend.finish(request(state, "delete"), {cancelled: true}, "", "");
        content.listItem.focusList(); keyClick(Qt.Key_D, Qt.AltModifier);
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: Object.assign({}, challenge, {token: "second", app_key: "named:Chat"})}, "", "");
        state.confirmDelete();
        verify(state.deletePending);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "second", cancel: false});
        const before = calls.length; state.confirmDelete(); compare(calls.length, before);
        state.backend.finish(request(state, "delete"), {}, "Connection lost; refresh before retrying", "");
        verify(!state.deletePending); verify(state.lastError.length > 0);
        compare(controller.visibleApps.length, 2, "failure cannot optimistically remove notifications");
        content.destroy();
    }
    function test_cardDeleteIsBorderlessAndRecordScopedWithoutMessageNavigation() {
        const {state, controller, content} = make();
        controller.openDetails();
        controller.timeline.snapshot = {recent: [preview(1000, "named:Chat")], dates: [], date: "", next_offset: null};
        tryVerify(() => findChild(content, "notificationCard-1000:1000000:delete") !== null);
        tryCompare(controller, "detailsExpansionProgress", 1);
        const list = findChild(content, "notificationTimelineList");
        showRow(list, 0, ListView.Contain);
        const button = findChild(content, "notificationCard-1000:1000000:delete");
        compare(button.border.width, 0);
        verify(!findChild(content, "notificationCard-1000:1000000:read"));
        mouseClick(button);
        const prepare = calls.filter(c => c.method === "notifications.prepareDelete").pop();
        compare(prepare.params, {app_key: "named:Chat", selected: {id: 1000, created: 1000000}});
        compare(controller.detailsTab, "notifications");
        compare(controller.tabs.length, 2);
        state.cancelDelete();
        content.destroy();
    }
    function test_latePrepareAfterClosureIsCancelledWithoutOpeningModal() {
        const {state, content} = make();
        state.prepareDelete("named:Chat", null, "Chat");
        const id = request(state, "prepare-delete");
        state.uiActive = false;
        state.backend.finish(id, {delete_confirmation: {token: "late", count: 3, expires_unix_ms: Date.now() + 60000}}, "", "");
        compare(state.deleteConfirmation, null);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "late", cancel: true});
        content.destroy();
    }
    function timelinePage(offset, ids, next) {
        return {view: "timeline", epoch: "epoch", revision: "1", query: "", app_key: "named:Chat", date: "older", period_day: "2026-10-08", recent: [1000,999,998].map(id => preview(id, "named:Chat")), dates: ["today", "week", "month", "older"].map(key => ({key: key, count: key === "older" ? 40 : 0})), count: 40, total_rows: 40, offset: offset, next_offset: next, anchor_reached: true,
            entries: ids.map(id => ({key: id + ":" + id * 1000, preview: preview(id, "named:Chat"), members: [{id: id, created: id * 1000}]}))};
    }
    function test_recentThreeThenClosedPeriodsAndPrimarySecondaryActions() {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        const context = () => ({view: "timeline", generation: timeline.generation, appKey: timeline.appKey, query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping, offset: 0, replacing: true, revision: state.observedHistoryRevision});
        const value = timelinePage(0, [], null);
        value.date = ""; value.count = 0; value.total_rows = 0;
        timeline.receive(context(), value, "", "");
        compare(timeline.error, "");
        tryVerify(() => findChild(content, "notificationTimelineList") !== null);
        const list = findChild(content, "notificationTimelineList");
        tryCompare(list, "count", 4);
        verify(list.height > 300, "exercise a real clipped detail viewport");
        compare(list.rows.map(row => row.kind), ["message", "message", "message", "date"]);
        compare(list.rows.slice(3).map(row => row.key), ["older"], "empty periods have neither title nor control");
        verify(timeline.collapsed);
        const actions = findChild(content, "surfaceActionRow");
        compare(actions.primaryActions.map(action => action.id), ["silence"]);
        compare(actions.secondaryActions.map(action => action.id), ["reset", "delete"]);
        const primary = findChild(content, "detailAction:silence");
        const reset = findChild(content, "detailAction:reset");
        verify(primary.width > reset.width);
        verify(primary.mapToItem(content, 0, 0).y < reset.mapToItem(content, 0, 0).y);
        verify(!content.detailsNavigation.targets.includes(primary) && !content.detailsNavigation.targets.includes(reset));
        tryCompare(controller, "detailsExpansionProgress", 1);
        showRow(list, 3, ListView.Contain);
        const older = findChild(content, "notificationDate-older");
        verify(older !== null);
        mouseClick(older.button);
        compare(timeline.requestedDate, "older");
        compare(list.rows.filter(row => row.kind === "message").length, 3, "recent cards stay visible while another period loads");
        const period = timelinePage(0, [100,99], null);
        period.count = 2; period.total_rows = 2; period.dates[3].count = 2;
        timeline.receive(context(), period, "", "");
        compare(timeline.error, "");
        tryCompare(list, "count", 6);
        showRow(list, 3, ListView.Contain);
        mouseClick(findChild(content, "notificationDate-older").button);
        tryCompare(list, "count", 4);
        const empty = timelinePage(0, [], null);
        empty.count = 0; empty.total_rows = 0; empty.dates[3].count = 0;
        timeline.receive(context(), empty, "", "");
        tryCompare(list, "count", 3);
        tryVerify(() => !findChild(content, "notificationDate-older"));
        const arrival = Object.assign({}, empty, {dates: empty.dates.map(d => ({key: d.key, count: d.key === "today" ? 1 : 0}))});
        timeline.receive(context(), arrival, "", "");
        tryCompare(list, "count", 4);
        compare(list.rows[3].key, "today", "nonempty periods return on acknowledged arrival");
        controller.setDetailsTab("controls");
        tryVerify(() => findChild(content, "notificationAppDelivery") !== null);
        compare(findChild(content, "surfaceActionRow").primaryActions[0].id, "silence");
        state.notifications = Object.assign({}, state.notifications, {app_policies: {"named:Chat": {silent: true, group_similar: false, bypass_dnd: true}}});
        keyClick(Qt.Key_E, Qt.AltModifier);
        compare(policyCalls().length, 1);
        compare(policyCalls()[0].params.policy, {silent: false, until_unix_ms: null, group_similar: true, bypass_dnd: false});
        content.destroy();
    }
    function test_timelineRefreshStagesThroughAnchorAndKeepsViewport() {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older"; timeline.collapsed = false;
        const context = offset => ({view: "timeline", generation: timeline.generation, appKey: timeline.appKey, query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping, offset: offset, replacing: true, revision: state.observedHistoryRevision});
        const ids = Array.from({length: 20}, (_, i) => 100 - i);
        timeline.receive(context(0), timelinePage(0, ids, 20), "", "");
        tryVerify(() => findChild(content, "notificationTimelineList") !== null);
        const list = findChild(content, "notificationTimelineList");
        tryVerify(() => list.count > 10);
        tryCompare(controller, "detailsExpansionProgress", 1);
        showRow(list, 10, ListView.Beginning);
        const index = list.firstVisibleIndex();
        verify(index >= 0);
        const key = list.model.get(index).resultKey;
        const offset = list.itemAtIndex(index).y - list.contentY;
        timeline.staging = [];
        const first = timelinePage(0, [101].concat(ids.slice(0, 19)), 20);
        first.count = 21; first.total_rows = 21; first.dates[3].count = 21; first.anchor_reached = false;
        first.recent = [1001,1000,999].map(id => preview(id, "named:Chat"));
        timeline.receive(context(0), first, "", "");
        compare(timeline.entries[0].preview.id, 100, "an incomplete refreshed window remains private");
        compare(timeline.snapshot.recent[0].id, 1000, "recent previews and period rows publish atomically");
        const second = timelinePage(20, [81], null);
        second.count = 21; second.total_rows = 21; second.dates[3].count = 21;
        second.recent = first.recent;
        timeline.receive(context(20), second, "", "");
        tryCompare(timeline, "busy", false);
        tryVerify(() => !list.scrollSuspended && list.firstVisibleIndex() >= 0 && list.model.get(list.firstVisibleIndex()).resultKey === key);
        const restored = list.firstVisibleIndex();
        verify(restored >= 0);
        compare(list.model.get(restored).resultKey, key);
        verify(Math.abs(list.itemAtIndex(restored).y - list.contentY - offset) < 2);
        compare(timeline.entries.length, 21);
        compare(timeline.snapshot.recent[0].id, 1001);
        content.destroy();
    }
    function test_timelineAtomicWindowsRejectDuplicateAndStaleReplies() {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older"; timeline.collapsed = false;
        const context = offset => ({view: "timeline", generation: timeline.generation, appKey: timeline.appKey, query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping, offset: offset, replacing: offset === 0, revision: state.observedHistoryRevision});
        const ids = Array.from({length: 20}, (_, i) => 100 - i);
        timeline.receive(context(0), timelinePage(0, ids, 20), "", "");
        compare(timeline.entries.length, 20);
        const good = JSON.stringify(timeline.entries);
        timeline.receive(context(20), timelinePage(20, ids, null), "", "");
        verify(timeline.error.length > 0); compare(JSON.stringify(timeline.entries), good);
        timeline.error = "";
        const midnight = timelinePage(20, ids.map(id => id - 20), null);
        midnight.period_day = "2026-10-09";
        timeline.receive(context(20), midnight, "", "");
        compare(JSON.stringify(timeline.entries), good); verify(timeline.dirty, "calendar snapshots cannot be mixed");
        const duplicateRecent = timelinePage(0, [1000].concat(ids.slice(1)), 20);
        timeline.receive(context(0), duplicateRecent, "", "");
        verify(timeline.error.length > 0, "recent previews cannot duplicate a period record");
        compare(JSON.stringify(timeline.entries), good);
        timeline.error = "";
        const stale = context(20);
        state.applySummary({available: true, history_revision: 2, app_policies: {}});
        timeline.receive(stale, timelinePage(20, ids.map(id => id - 20), null), "", "");
        compare(JSON.stringify(timeline.entries), good); verify(timeline.dirty);
        const generation = timeline.generation;
        timeline.requestedDate = "week";
        timeline.receive(Object.assign({}, stale, {generation: generation}), timelinePage(20, ids, null), "", "");
        compare(timeline.entries.length, 0, "superseded dates cannot repopulate the viewport");
        content.destroy();
    }
}
