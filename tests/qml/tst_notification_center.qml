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
        const modal = findChild(content, "notificationDeleteConfirmation");
        tryCompare(findChild(modal, "detailAction:reject"), "activeFocus", true);
        verify(modal.compactPresentation && !modal.actionSummaryVisible);
        verify(!findChild(modal, "modalDetail").visible);
        keyClick(Qt.Key_Tab);
        verify(findChild(modal, "detailAction:accept").activeFocus);
        keyClick(Qt.Key_Return);
        verify(state.deletePending);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "second", cancel: false});
        const before = calls.length; state.confirmDelete(); compare(calls.length, before);
        state.backend.finish(request(state, "delete"), {}, "Connection lost; refresh before retrying", "");
        verify(!state.deletePending); verify(state.lastError.length > 0);
        compare(controller.visibleApps.length, 2, "failure cannot optimistically remove notifications");
        content.destroy();
    }
    function test_deleteCountsRejectMalformedAcknowledgements_data() {
        return [{tag: "0", count: -1}];
    }
    function test_deleteCountsRejectMalformedAcknowledgements(data) {
        const {state, content} = make();
        const challenge = {token: "owned", count: data.count, app_key: "named:Chat", expires_unix_ms: Date.now() + 60000};
        verify(state.prepareDelete("named:Chat", null, "Chat"));
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: challenge}, "", "");
        compare(state.deleteConfirmation, null);
        verify(!state.deletePreparing && state.lastError.length > 0);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "owned", cancel: true});
        state.backend.finish(request(state, "delete"), {cancelled: true}, "", "");
        verify(state.prepareDelete("named:Chat", null, "Chat"));
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: Object.assign({}, challenge, {count: 1})}, "", "");
        state.confirmDelete();
        verify(state.deletePending);
        const before = calls.length;
        state.backend.finish(request(state, "delete"), {deleted: data.count}, "", "");
        verify(!state.deletePending && state.lastError.length > 0);
        compare(calls.length, before, "malformed acknowledgement neither announces deletion nor replays it");
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
    function test_malformedTimelineKeepsPublishedWindow_data() {
        return [
            {tag: "foreign-preview", patch: {recent: [preview(1000, "named:Mail")]}}
        ];
    }
    function test_malformedTimelineKeepsPublishedWindow(data) {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older";
        const context = {view: "timeline", generation: timeline.generation, appKey: timeline.appKey,
            query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping,
            offset: 0, replacing: true, revision: state.observedHistoryRevision};
        const good = timelinePage(0, Array.from({length: 20}, (_, i) => 100 - i), 20);
        timeline.receive(context, good, "", "");
        compare(timeline.entries.length, 20);
        const published = JSON.stringify(timeline.entries);
        timeline.busy = true;
        timeline.receive(context, Object.assign({}, good, data.patch), "", "");
        verify(timeline.error.length > 0);
        verify(!timeline.busy);
        compare(timeline.staging, null);
        compare(JSON.stringify(timeline.entries), published);
        compare(timeline.snapshot, good);
        content.destroy();
    }
    function test_expandedStackKeepsMemberDeleteIdentity() {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older";
        timeline.collapsed = false;
        const value = timelinePage(0, [100], null);
        value.count = 2; value.total_rows = 1; value.dates[3].count = 2;
        value.entries[0].members.push({id: 99, created: 99000});
        timeline.receive({view: "timeline", generation: timeline.generation, appKey: timeline.appKey,
            query: timeline.query, date: "older", grouping: timeline.grouping, offset: 0,
            replacing: true, revision: state.observedHistoryRevision}, value, "", "");
        compare(timeline.error, "");
        tryVerify(() => findChild(content, "notificationTimelineList") !== null);
        const list = findChild(content, "notificationTimelineList");
        tryCompare(list, "count", 5);
        tryCompare(controller, "detailsExpansionProgress", 1);
        showRow(list, 4, ListView.Contain);
        mouseClick(findChild(content, "notificationCard-100:100000:expand"));
        tryCompare(list, "count", 7);
        compare(list.rows.slice(-2).map(row => row.key), ["member:100:100000", "member:99:99000"]);
        showRow(list, 6, ListView.Contain);
        mouseClick(findChild(content, "notificationCard-member:99:99000:delete"));
        const prepare = calls.filter(c => c.method === "notifications.prepareDelete").pop();
        compare(prepare.params, {app_key: "named:Chat", selected: {id: 99, created: 99000}});
        compare(controller.detailsTab, "notifications", "member commands cannot open a hidden reader");
        content.destroy();
    }
    function test_unownedTimelineRepliesKeepPendingWindow_data() {
        return [
            {tag: "generation", patch: {generation: -1}}
        ];
    }
    function test_unownedTimelineRepliesKeepPendingWindow(data) {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older";
        const context = {view: "timeline", generation: timeline.generation, appKey: timeline.appKey,
            query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping,
            offset: 0, replacing: true, revision: state.observedHistoryRevision};
        timeline.receive(context, Object.assign(timelinePage(0, [100], 1), {anchor_reached: false}), "", "");
        verify(timeline.busy);
        const staged = JSON.stringify(timeline.staging);
        for (const failure of ["", "Unrelated failure"]) {
            state.centerResponse(Object.assign({}, context, data.patch), null, failure, "history-cursor-stale");
            compare(JSON.stringify(timeline.staging), staged);
            verify(timeline.busy);
            compare(timeline.error, "");
        }
        controller.uiActive = false;
        compare(timeline.staging, null, "hiding discards the cursor together with its entries");
        state.centerResponse(context, timelinePage(1, [99], 2), "", "");
        compare(timeline.staging, null);
        verify(!timeline.busy);
        content.destroy();
    }
    function test_rejectedTimelineContinuationDiscardsWholeStaging_data() {
        return [
            {tag: "failure", failure: "History unavailable", code: "", patch: {}}
        ];
    }
    function test_rejectedTimelineContinuationDiscardsWholeStaging(data) {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older";
        const context = offset => ({view: "timeline", generation: timeline.generation, appKey: timeline.appKey,
            query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping,
            offset: offset, replacing: true, revision: state.observedHistoryRevision});
        const published = timelinePage(0, [101], 1);
        timeline.receive(context(0), published, "", "");
        let publications = 0;
        timeline.viewChanged.connect(() => publications++);
        timeline.receive(context(0), Object.assign(timelinePage(0, [100], 1), {anchor_reached: false}), "", "");
        compare(timeline.staging.entries.length, 1);
        compare(timeline.staging.period_day, published.period_day);
        timeline.receive(context(1), Object.assign(timelinePage(1, [99], 2), data.patch), data.failure, data.code);
        compare(timeline.staging, null);
        verify(!timeline.busy);
        compare(timeline.snapshot, published);
        compare(timeline.entries[0].preview.id, 101);
        compare(publications, 0, "neither staging nor rejection can publish a partial window");
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
